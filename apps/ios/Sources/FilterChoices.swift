import Foundation

/**
 * The choices the filter sheet offers, as pure functions of the loaded stations and `Filters`,
 * so the sheet only draws them and the tests can check them without a view.
 */

/** Brands in the grid: every brand starts on, and a tap turns one off. */
enum BrandChoice {
    /** Families with at least one loaded station, in the brand table's order. */
    static func present(in stations: [Station]) -> [BrandFamily] {
        let ids = Set(stations.map(\.family.id))
        return BrandFamily.all.filter { ids.contains($0.id) }
    }

    /** Whether stations of brand `id` pass `filters`' brand setting. */
    static func isOn(_ id: String, in filters: Filters) -> Bool {
        filters.brands.isEmpty || filters.brands.contains(id) != filters.hideBrands
    }

    /**
     * Flips one brand. The grid keeps its choice as the brands to hide, so a brand that loads later
     * shows by default; an "only these" choice is turned into the same hidden set among `present`.
     */
    static func toggle(_ id: String, in filters: inout Filters, among present: [String]) {
        var off = filters.hideBrands || filters.brands.isEmpty
            ? filters.brands
            : Set(present.filter { !filters.brands.contains($0) })
        if off.contains(id) { off.remove(id) } else { off.insert(id) }
        filters.brands = off
        // With nothing hidden, go back to the default so Reset reads as having nothing to clear.
        filters.hideBrands = !off.isEmpty
    }

    /** "All brands" while every present brand is on, otherwise "5 of 8". */
    static func countLine(on: Int, of total: Int) -> String {
        on == total ? "All brands" : "\(on) of \(total)"
    }
}

/** How recently a price was reported, as the four dots on the sheet's scale. */
enum FreshnessStep: Int, CaseIterable, Identifiable, Sendable {
    case sixHours, day, threeDays, week
    var id: Int { rawValue }

    /**
     * The `Filters.freshHours` value. "A week" is no limit: prices older than a week are not ranked
     * anyway (`Station.currentFor`).
     */
    var hours: Int? {
        switch self {
        case .sixHours: 6
        case .day: 24
        case .threeDays: 72
        case .week: nil
        }
    }

    /** Under the dot. */
    var short: String {
        switch self {
        case .sixHours: "6 h"
        case .day: "24 h"
        case .threeDays: "3 days"
        case .week: "A week"
        }
    }

    /** Beside the section title. */
    var long: String {
        switch self {
        case .sixHours: "6 hours"
        case .day: "24 hours"
        case .threeDays: "3 days"
        case .week: "A week"
        }
    }

    /** The step showing `hours`; a limit between steps shows on the next wider one. */
    init(hours: Int?) {
        guard let hours else { self = .week; return }
        self = Self.allCases.first { ($0.hours ?? .max) >= hours } ?? .week
    }
}

/** Station counts per price band, for the sheet's histogram. */
struct PriceHistogram: Equatable, Sendable {
    struct Bin: Equatable, Sendable {
        let from: Double
        let to: Double
        let count: Int
        var mid: Double { (from + to) / 2 }
    }

    let bins: [Bin]
    var low: Double? { bins.first?.from }
    var high: Double? { bins.last?.to }
    var tallest: Int { bins.map(\.count).max() ?? 0 }

    /** `binCount` equal-width bands from the lowest to the highest price; the highest lands in the last band. */
    init(_ prices: [Double], binCount: Int = 16) {
        guard let lo = prices.min(), let hi = prices.max(), binCount > 0 else { bins = []; return }
        guard hi > lo else { bins = [Bin(from: lo, to: hi, count: prices.count)]; return }
        let width = (hi - lo) / Double(binCount)
        var counts = Array(repeating: 0, count: binCount)
        for p in prices { counts[min(binCount - 1, Int((p - lo) / width))] += 1 }
        bins = counts.enumerated().map { i, c in
            Bin(from: lo + Double(i) * width, to: i == binCount - 1 ? hi : lo + Double(i + 1) * width, count: c)
        }
    }

    /**
     * Current prices for `fuel` at the stations inside `viewport` (all of them before the map
     * reports one). Filters are not applied: the chart shows what the tier chips choose from.
     */
    static func pricesInView(_ stations: [Station], fuel: FuelType, viewport: Viewport?, now: Date = .now) -> [Double] {
        stations.compactMap { s in
            guard s.hasCurrentPrice(fuel, now: now), viewport?.contains(lat: s.lat, lng: s.lng) ?? true else { return nil }
            return s.price(fuel)?.price
        }
    }

    /** The tier cut points of `range` in one line, under the chart. */
    static func cutLine(_ range: PriceRange) -> String {
        let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        return "cheap to \(range.cheapBelow.formatted(format)), pricey over \(range.midBelow.formatted(format))"
    }
}

extension StationOrder {
    /** The list header's phrase for this order. */
    var caption: String {
        switch self {
        case .cheapest: "cheapest first"
        case .nearest: "nearest first"
        case .newest: "newest price first"
        }
    }

    /**
     * `stations` (cheapest first, as `Store.ranked` gives them) in this order. Ties keep their
     * cheapest-first position; a station without a distance or price sorts last.
     */
    func sorted(_ stations: [Station], fuel: FuelType) -> [Station] {
        switch self {
        case .cheapest:
            return stations
        case .nearest:
            return stable(stations) { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
        case .newest:
            let never = Date.distantPast
            return stable(stations) { ($0.price(fuel)?.updatedAt ?? never) > ($1.price(fuel)?.updatedAt ?? never) }
        }
    }

    private func stable(_ stations: [Station], by before: (Station, Station) -> Bool) -> [Station] {
        stations.enumerated()
            .sorted { before($0.element, $1.element) || (!before($1.element, $0.element) && $0.offset < $1.offset) }
            .map(\.element)
    }
}

/** The sheet's confirm button. */
enum ShowStations {
    /** How many stations in view pass the filters; `ranked` is the count across the whole fetch. */
    static func title(inView: Int, ranked: Int) -> String {
        if ranked == 0 { return "No matches" }
        switch inView {
        case 0: return "Show stations"
        case 1: return "Show 1 station"
        default: return "Show \(inView) stations"
        }
    }
}
