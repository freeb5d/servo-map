import AppIntents

// Lets Siri, Shortcuts and widget configuration offer the fuels by name.
extension FuelType: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Fuel"
    static let caseDisplayRepresentations: [FuelType: DisplayRepresentation] = [
        .u91: "U91", .e10: "E10", .u95: "U95", .u98: "U98", .diesel: "Diesel",
    ]
}

/** Prices shown by Siri and widgets, which have no location of their own yet. */
enum Nearby {
    static let place = "Sydney CBD"

    static func cheapest(_ fuel: FuelType, limit: Int = 3) async throws -> [Station] {
        let all = try await API().stations(fuel: fuel, lat: Store.sydney.lat, lng: Store.sydney.lng, radiusKm: 20)
        // Same rule as the app: only a current price can be quoted as the cheapest.
        let fresh = all.filter { $0.hasCurrentPrice(fuel) }
        return Array(fresh.sorted { ($0.price(fuel)?.price ?? .infinity) < ($1.price(fuel)?.price ?? .infinity) }.prefix(limit))
    }
}
