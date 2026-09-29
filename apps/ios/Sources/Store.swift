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
    var located: Bool { placeName == "you" }

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

    /** Stations after filters, cheapest first; prices older than a day are left out of the ranking. */
    private(set) var ranked: [Station] = []
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
        loading = true
        defer { loading = false }
        do {
            async let s = api.stations(fuel: fuel, lat: center.lat, lng: center.lng, radiusKm: 20)
            async let t = api.trends(state: "nsw")
            async let live = api.liveStates()
            (stations, history) = try await (s, t)
            liveStates = ((try? await live) ?? []).map { $0.uppercased() }
            failed = false
        } catch {
            failed = true
        }
    }

    func loadStations() async {
        loading = true
        defer { loading = false }
        do {
            stations = try await api.stations(fuel: fuel, lat: center.lat, lng: center.lng, radiusKm: 20)
            failed = false
        } catch {
            failed = true
        }
    }

    private func derive() {
        let prices = stations.compactMap { $0.price(fuel)?.price }
        ranked = matching(filters)
        range = PriceRange(prices)
        localAverage = prices.isEmpty ? nil : prices.reduce(0, +) / Double(prices.count)
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
            return p.updatedAt > now.addingTimeInterval(-86_400)
        }
        .map { ($0, $0.price(fuel)?.price ?? .infinity) }
        .sorted { $0.1 < $1.1 }
        .map(\.0)
    }

    /** Where the cheapest price sits in recent history and against the local average, in one line. */
    var verdictLine: String? {
        guard let cheapest = ranked.first?.price(fuel)?.price else { return nil }
        let parts = [TrendMath.verdict(trend),
                     localAverage.map { "\(($0 - cheapest).formatted(.number.precision(.fractionLength(1))))¢ below the local average." }]
        let text = parts.compactMap { $0 }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    func move(to lat: Double, _ lng: Double, name: String) async {
        center = (lat, lng)
        placeName = name
        await loadStations()
    }

    func isSaved(_ s: Station) -> Bool { savedIDs.contains(s.id) }
    func toggleSaved(_ s: Station) {
        if let i = savedIDs.firstIndex(of: s.id) { savedIDs.remove(at: i) } else { savedIDs.append(s.id) }
    }
}
