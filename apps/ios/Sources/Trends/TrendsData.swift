import Foundation
import Observation

/**
 * What the Trends tab reads: every live state's daily series (all fuels) and today's city figures per
 * fuel. Kept apart from `Store`, whose history covers NSW only for the map's verdict line.
 */
@MainActor @Observable
final class TrendsData {
    /** state code (lower case) → fuel → daily series, oldest first. */
    private(set) var series: [String: [FuelType: [Snapshot]]] = [:]
    private(set) var cities: [FuelType: [CityInsight]] = [:]
    private(set) var loadingStates = false
    private(set) var failed = false
    private let api = API()

    init() {}

    /** Preloaded data for tests and previews; nothing is fetched. */
    init(history: [String: [Snapshot]], cities: [FuelType: [CityInsight]] = [:]) {
        series = history.mapValues(Self.group)
        self.cities = cities
    }

    func series(_ state: String, _ fuel: FuelType) -> [Snapshot] { series[state]?[fuel] ?? [] }

    /** Each state's series for one fuel, keyed by state code, leaving out states without that fuel. */
    func byState(_ fuel: FuelType) -> [String: [Snapshot]] {
        series.compactMapValues { $0[fuel]?.isEmpty == false ? $0[fuel] : nil }
    }

    /** The latest snapshot of every fuel in a state. */
    func latestByFuel(_ state: String) -> [FuelType: Snapshot] {
        (series[state] ?? [:]).compactMapValues(\.last)
    }

    /** Fetches every state's history at once; a state that fails keeps what was loaded before. */
    func load(states: [String]) async {
        let codes = states.map { $0.lowercased() }
        guard !codes.isEmpty else { return }
        loadingStates = true
        defer { loadingStates = false }
        let api = api
        let results = await withTaskGroup(of: (String, [Snapshot]?).self) { group in
            for code in codes {
                group.addTask { (code, try? await api.trends(state: code)) }
            }
            var out: [(String, [Snapshot]?)] = []
            for await result in group { out.append(result) }
            return out
        }
        var failures = 0
        for (code, snapshots) in results {
            if let snapshots { series[code] = Self.group(snapshots) } else { failures += 1 }
        }
        failed = failures == codes.count
    }

    /** Today's city figures for a fuel; an earlier answer stays on screen if the fetch fails. */
    func loadCities(_ fuel: FuelType) async {
        do {
            cities[fuel] = try await api.cityInsights(fuel: fuel)
        } catch {
            failed = cities[fuel] == nil
        }
    }

    private static func group(_ snapshots: [Snapshot]) -> [FuelType: [Snapshot]] {
        var out: [FuelType: [Snapshot]] = [:]
        for s in snapshots.sorted(by: { $0.date < $1.date }) {
            if let fuel = FuelType(rawValue: s.fuel) { out[fuel, default: []].append(s) }
        }
        return out
    }
}
