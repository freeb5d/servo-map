import Foundation
import Observation

/** Filters shared by the map sheet and the filter form. */
struct Filters: Equatable, Sendable {
    var maxPrice: Double? = nil
    var radiusKm: Int? = nil
    var freshHours: Int? = nil
    var brands: Set<String> = []
    /** Whether `brands` lists the only families to show, or the ones to hide. */
    var hideBrands = false
    var hideMembersOnly = false
    /** Other fuels a station must also sell. */
    var alsoSells: Set<FuelType> = []

    var activeCount: Int {
        [maxPrice != nil, radiusKm != nil, freshHours != nil, !brands.isEmpty, hideMembersOnly, !alsoSells.isEmpty].filter { $0 }.count
    }
}

@MainActor @Observable
final class Store {
    static let sydney = (lat: -33.8688, lng: 151.2093)

    /** Where prices are fetched around; starts at Sydney CBD until the user shares a location. */
    private(set) var center = Store.sydney
    private(set) var placeName = "Sydney CBD"
    /** Where the user is, once they have shared it. Kept when the map moves elsewhere. */
    private(set) var userLocation: (lat: Double, lng: Double)?
    var located: Bool { userLocation != nil }

    /** The part of the map the user can see (not under the sheet); nil until the map reports it. */
    var viewport: Viewport? { didSet { if viewport != oldValue { deriveInView() } } }
    /** Ranked stations inside `viewport`, cheapest first: the map's "cheapest" follows what is on screen. */
    private(set) var inView: [Station] = []
    /**
     * `inView.first`, kept on its own so the map depends on it alone: Observation skips an
     * assignment of an equal value, so a settle that leaves the same station cheapest does not
     * redraw every annotation, while the list below still follows `inView`.
     */
    private(set) var cheapestInView: Station?

    var fuel: FuelType = .u91 {
        didSet { derive(); Task { await loadStations() } }
    }
    var filters = Filters() { didSet { derive() } }
    private(set) var stations: [Station] = [] { didSet { derive() } }
    /** Daily history for every fuel; `trend` narrows it to the selected one. */
    private(set) var history: [Snapshot] = [] { didSet { byFuel = Dictionary(grouping: history, by: \.fuel) } }
    private var byFuel: [String: [Snapshot]] = [:]
    var trend: [Snapshot] { byFuel[fuel.rawValue] ?? [] }
    func trend(for fuel: FuelType) -> [Snapshot] { byFuel[fuel.rawValue] ?? [] }

    // Derived once per change of stations, filters or fuel. Views read these on every redraw (the
    // map reads `range` for every annotation), and recomputing them each time cost ~110 ms a frame.

    /** Stations after filters, cheapest first; prices more than a week old are left out (see `outdated`). */
    private(set) var ranked: [Station] = []
    /** Stations with a price for the fuel that is too old to rank; the map still shows them. */
    private(set) var outdated: [Station] = []
    /** How far around `center` stations are fetched; follows the map's zoom. */
    private(set) var radiusKm = 20
    /** Whether the last fetch hit the API's cap, so it holds only the cheapest stations around `center`. */
    var fetchWasCapped: Bool { stations.count >= API.stationLimit }
    /** Price tiers across every station nearby for the selected fuel. */
    private(set) var range = PriceRange([])
    /** Mean price nearby for the selected fuel. */
    private(set) var localAverage: Double?
    private(set) var loading = false
    /** Upper-case codes of states with live prices, from /metadata. */
    private(set) var liveStates: [String] = []
    private(set) var failed = false
    var savedIDs: [String] = UserDefaults.standard.stringArray(forKey: "saved") ?? [] {
        didSet { UserDefaults.standard.set(savedIDs, forKey: "saved") }
    }

    private let api = API()
    /** Bumped by each fetch of stations; a response that is no longer the latest is dropped. */
    private var stationsRequest = 0

    init(fuel: FuelType = .u91) {
        self.fuel = fuel
    }

    /** Preloaded store for tests and previews; nothing is fetched. */
    init(stations: [Station], history: [Snapshot] = [], fuel: FuelType = .u91) {
        self.stations = stations
        self.history = history
        self.fuel = fuel
        // didSet does not run for assignments in init.
        byFuel = Dictionary(grouping: history, by: \.fuel)
        derive()
    }

    func load() async {
        stationsRequest += 1
        let request = stationsRequest
        loading = true
        do {
            async let s = api.stations(fuel: fuel, lat: center.lat, lng: center.lng, radiusKm: radiusKm)
            async let t = api.trends(state: "nsw")
            async let live = api.liveStates()
            let (fetched, trend) = try await (s, t)
            history = trend
            liveStates = ((try? await live) ?? []).map { $0.uppercased() }
            // A pan or fuel change during the first load owns the station list now.
            if request == stationsRequest { stations = fetched; failed = false }
        } catch {
            if request == stationsRequest { failed = true }
        }
        if request == stationsRequest { loading = false }
    }

    /**
     * Fetches stations around `center`. Pans and fuel changes can overlap fetches; only the latest
     * one's result (or failure) is kept, so a slow earlier response never replaces a newer area.
     */
    func loadStations() async {
        stationsRequest += 1
        let request = stationsRequest
        loading = true
        let result: Result<[Station], Error>
        do {
            result = .success(try await api.stations(fuel: fuel, lat: center.lat, lng: center.lng, radiusKm: radiusKm))
        } catch {
            result = .failure(error)
        }
        guard request == stationsRequest else { return }
        loading = false
        switch result {
        case .success(let fetched): stations = fetched; failed = false
        case .failure: failed = true
        }
    }

    private func deriveInView() {
        if let viewport {
            inView = ranked.filter { viewport.contains(lat: $0.lat, lng: $0.lng) }
        } else {
            inView = ranked
        }
        cheapestInView = inView.first
    }

    /** Records the user's position; the map keeps showing it however far they pan away. */
    func setUserLocation(_ lat: Double, _ lng: Double) {
        userLocation = (lat, lng)
    }

    private func derive() {
        let prices = stations.compactMap { $0.price(fuel)?.price }
        ranked = matching(filters)
        let now = Date()
        outdated = stations.filter { $0.price(fuel) != nil && !$0.hasCurrentPrice(fuel, now: now) }
        range = PriceRange(prices)
        localAverage = prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count)
        deriveInView()
    }

    /** Stations passing `f`, cheapest first; the filter form uses it to preview counts. */
    func matching(_ f: Filters) -> [Station] {
        let filters = f
        let now = Date()
        // Price is looked up once per station, not once per comparison in the sort.
        return stations.filter { s in
            guard let p = s.price(fuel) else { return false }
            if let max = filters.maxPrice, p.price > max { return false }
            if let km = filters.radiusKm, (s.distance ?? 0) > Double(km) { return false }
            if let h = filters.freshHours, p.updatedAt < now.addingTimeInterval(Double(-h) * 3600) { return false }
            if !filters.brands.isEmpty, filters.brands.contains(s.family.id) == filters.hideBrands { return false }
            if filters.alsoSells.contains(where: { s.price($0) == nil }) { return false }
            if filters.hideMembersOnly, s.family.group == .members { return false }
            return s.hasCurrentPrice(fuel, now: now)
        }
        .map { ($0, $0.price(fuel)?.price ?? .infinity) }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    /** Where the cheapest price on the map sits in recent history and against the local average, in one line. */
    var verdictLine: String? {
        guard let cheapest = inView.first?.price(fuel)?.price else { return nil }
        let againstAverage = localAverage.flatMap { avg -> String? in
            let d = avg - cheapest
            guard abs(d) >= 0.05 else { return nil }
            return "\(abs(d).formatted(.number.precision(.fractionLength(1))))¢ \(d > 0 ? "below" : "above") the local average."
        }
        let parts = [TrendMath.verdict(trend), againstAverage]
        let text = parts.compactMap { $0 }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    /** A radius the map's zoom asks for, clamped to what the list can use (5 to 50 km). */
    nonisolated static func fetchRadius(_ km: Int) -> Int { min(max(km, 5), 50) }

    /** Moves the fetch area; a new radius (from the map's zoom) is clamped by `fetchRadius`. */
    func move(to lat: Double, _ lng: Double, name: String, radiusKm: Int? = nil) async {
        if let radiusKm { self.radiusKm = Store.fetchRadius(radiusKm) }
        center = (lat, lng)
        placeName = name
        await loadStations()
    }

    func isSaved(_ s: Station) -> Bool { savedIDs.contains(s.id) }
    func toggleSaved(_ s: Station) {
        if let i = savedIDs.firstIndex(of: s.id) { savedIDs.remove(at: i) } else { savedIDs.append(s.id) }
    }

    /** Follows a saved station the server now reports under another id, keeping its place in the list. */
    func adoptStationID(_ old: String, as new: String) {
        guard old != new, savedIDs.contains(old) else { return }
        var seen = Set<String>()
        savedIDs = savedIDs.map { $0 == old ? new : $0 }.filter { seen.insert($0).inserted }
    }
}

/** A latitude/longitude box, for what the map shows. */
struct Viewport: Equatable, Sendable {
    var minLat: Double, maxLat: Double, minLng: Double, maxLng: Double

    func contains(lat: Double, lng: Double) -> Bool {
        (minLat...maxLat).contains(lat) && (minLng...maxLng).contains(lng)
    }
}
