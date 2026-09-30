import Foundation

/** Facts read off today's city figures for the Cities and Timing pages. */
enum CityFacts {
    /**
     * The day per-station price history started (decision 0006). City history and the timing heatmap
     * are built from it, so they show "Collecting since" until enough of it exists.
     */
    static let historySince = "2026-09-30"
    /** Days of history before the "Cities over time" view opens. */
    static let cityHistoryDays = 30
    /** Days of history before the weekday by hour heatmap opens: four weeks, so each hour has four samples. */
    static let heatmapDays = 28

    /** Cities with a recent average, cheapest first. */
    static func ranked(_ cities: [CityInsight]) -> [CityInsight] {
        cities.filter { $0.average != nil }.sorted { ($0.average ?? 0, $0.name) < ($1.average ?? 0, $1.name) }
    }

    /** "Bunbury is cheapest at 232.2¢ on average. Launceston is 14.4¢ dearer." */
    static func cheapestFact(_ ranked: [CityInsight]) -> String? {
        guard let low = ranked.first, let lowAvg = low.average else { return nil }
        let head = "\(low.name) is cheapest at \(TrendFormat.cents(lowAvg))¢ on average."
        guard ranked.count > 1, let high = ranked.last, let highAvg = high.average, highAvg - lowAvg >= 0.05 else { return head }
        return "\(head) \(high.name) is \(TrendFormat.cents(highAvg - lowAvg))¢ dearer."
    }

    /** "within 20 km of each centre" when every city uses one radius. */
    static func radiusCaption(_ cities: [CityInsight]) -> String {
        let radii = Set(cities.map(\.radiusKm))
        guard radii.count == 1, let km = radii.first else { return "within each city's radius" }
        return "within \(km.formatted(.number.precision(.fractionLength(0...1)))) km of each centre"
    }

    /** The city whose distribution shows first: the one with the most stations. */
    static func defaultCity(_ cities: [CityInsight]) -> CityInsight? {
        cities.filter { $0.histogram != nil }.max { ($0.stationCount, $1.name) < ($1.stationCount, $0.name) }
    }

    /** "Two price points hold 139 stations: 238–240¢ and 240–242¢." The two fullest bins, cheaper first. */
    static func histogramFact(_ histogram: CityHistogram) -> String? {
        let top = histogram.bins.filter { $0.count > 0 }.sorted { $0.count > $1.count }.prefix(2).sorted { $0.lower < $1.lower }
        let range = { (b: CityHistogram.Bin) in "\(Int(b.lower))–\(Int(b.upper))¢" }
        switch top.count {
        case 1: return "Every station charges \(range(top[0]))."
        case 2: return "Two price points hold \(top[0].count + top[1].count) stations: \(range(top[0])) and \(range(top[1]))."
        default: return nil
        }
    }

    /** Cities by the share of stations reporting in the last day, highest first. */
    static func byReporting(_ cities: [CityInsight]) -> [CityInsight] {
        cities.filter { $0.reportedWithin24hShare != nil }
            .sorted { ($0.reportedWithin24hShare ?? 0, $1.name) > ($1.reportedWithin24hShare ?? 0, $0.name) }
    }

    private static let stateOrder = ["nsw", "act", "tas", "vic", "qld", "sa", "nt", "wa"]

    /**
     * Why WA's share is so different: FuelWatch has every station post each day's price, while the
     * other schemes record a price only when it changes. Names only the states shown.
     */
    static func reportingFact(states: [String]) -> String? {
        let codes = Set(states.map { $0.lowercased() })
        let others = stateOrder.filter { $0 != "wa" && codes.contains($0) }.map(StateName.short)
        let wa = codes.contains("wa") ? "WA stations post a price every day." : nil
        let rest = others.isEmpty ? nil
            : "In \(TrendFormat.list(others)) a station reports only when its price changes, so an old price is often still the current one."
        let text = [wa, rest].compactMap { $0 }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    /** "30 Oct": when a view that needs `days` of history opens. */
    static func opens(afterDays days: Int) -> String {
        TrendFormat.dayMonth(TrendFormat.adding(days, to: historySince))
    }
}
