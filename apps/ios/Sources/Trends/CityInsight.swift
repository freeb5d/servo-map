import Foundation

/** Counts of prices in equal-width bins, from `/insights/cities`. */
struct CityHistogram: Decodable, Hashable, Sendable {
    /** Lower edge of the first bin, cents per litre. */
    let start: Double
    let width: Double
    let counts: [Int]

    struct Bin: Hashable, Sendable {
        let lower: Double
        let upper: Double
        let count: Int
    }

    var bins: [Bin] {
        counts.enumerated().map { i, n in Bin(lower: start + Double(i) * width, upper: start + Double(i + 1) * width, count: n) }
    }

    var total: Int { counts.reduce(0, +) }
}

/**
 * One city's prices for a fuel today (`@servo-map/shared` `CityInsight`). `count`, `average`, `min`
 * and `max` use prices reported in the last 7 days; `median` and `histogram` use every price.
 */
struct CityInsight: Decodable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let state: String
    let radiusKm: Double
    let stationCount: Int
    let count: Int
    let average: Double?
    let min: Double?
    let max: Double?
    let median: Double?
    let reportedWithin24hShare: Double?
    let histogram: CityHistogram?

    enum CodingKeys: String, CodingKey {
        case id, name, state, count, average, min, max, median, histogram
        case radiusKm = "radius_km", stationCount = "station_count", reportedWithin24hShare = "reported_within_24h_share"
    }
}

struct CityInsights: Decodable, Sendable {
    let fuel: String
    let cities: [CityInsight]
}

extension API {
    /** Per-city figures for one fuel, computed by the worker from the current station data. */
    func cityInsights(fuel: FuelType) async throws -> [CityInsight] {
        let insights: CityInsights = try await get("insights/cities", ["fuel": fuel.rawValue])
        return insights.cities
    }
}
