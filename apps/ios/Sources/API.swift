import Foundation

/** Read-only client for the public ServoMap API; the same endpoints the web app uses. */
struct API: Sendable {
    static let base: URL = {
        #if DEBUG
        // `-apiBase http://127.0.0.1:8787/api/v1` points a debug build at a local `wrangler dev`.
        if let raw = UserDefaults.standard.string(forKey: StorageKey.apiBase), let url = URL(string: raw) { return url }
        #endif
        return URL(string: "https://api.servo-map.com/api/v1")!
    }()
    /** The public website: station share links and the car pictures resolve against it. */
    static let site = URL(string: "https://www.servo-map.com")!

    /** Most stations one nearby fetch returns; the cheapest come first, so a capped fetch drops the dearest. */
    static let stationLimit = 500

    private struct Envelope<T: Decodable>: Decodable { let data: T }
    private struct Trend: Decodable { let series: [Snapshot] }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: raw) { return date }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: raw) ?? .distantPast
        }
        return d
    }()

    /** One GET, unwrapped from the `{ status, data }` envelope; app-only endpoints extend API elsewhere. */
    func get<T: Decodable>(_ path: String, _ query: [String: String]) async throws -> T {
        var parts = URLComponents(url: Self.base.appending(path: path), resolvingAgainstBaseURL: false)!
        parts.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, response) = try await URLSession.shared.data(from: parts.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Self.decoder.decode(Envelope<T>.self, from: data).data
    }

    func stations(fuel: FuelType, lat: Double, lng: Double, radiusKm: Int) async throws -> [Station] {
        try await get("stations", [
            "fuel": fuel.rawValue, "lat": "\(lat)", "lng": "\(lng)",
            "radius": "\(radiusKm)", "limit": "\(Self.stationLimit)", "sort": "price_asc",
        ])
    }

    /** The shared car catalogue (decision 0004). */
    func vehicles(_ query: String, limit: Int = 30) async throws -> [Vehicle] {
        try await get("vehicles", ["q": query, "limit": "\(limit)"])
    }

    func vehicleMakes() async throws -> [String] {
        try await get("vehicles/makes", [:])
    }

    func search(_ query: String, fuel: FuelType) async throws -> [Station] {
        try await get("stations", ["q": query, "fuel": fuel.rawValue, "limit": "100", "sort": "price_asc"])
    }

    func station(id: String) async throws -> Station {
        try await get("stations/\(id)", [:])
    }

    private struct StateMeta: Decodable { let stationCount: Int
        enum CodingKeys: String, CodingKey { case stationCount = "station_count" } }

    /** States with at least one reporting station, e.g. ["nsw"]; the single source for coverage copy. */
    func liveStates() async throws -> [String] {
        let meta: [String: StateMeta] = try await get("metadata", [:])
        return meta.filter { $0.value.stationCount > 0 }.map(\.key).sorted()
    }

    /** Daily history for every fuel in a state. */
    func trends(state: String) async throws -> [Snapshot] {
        let trend: Trend = try await get("trends", ["state": state])
        return trend.series.sorted { $0.date < $1.date }
    }
}
