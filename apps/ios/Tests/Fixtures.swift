import Foundation
@testable import ServoMap

enum Fixture {
    static let now = Date()

    static func station(_ id: String, brand: String = "Metro Fuel", suburb: String = "Croydon",
                        u91: Double? = 225.9, diesel: Double? = nil, hoursOld: Double = 1, km: Double? = 3) -> Station {
        var prices: [FuelPrice] = []
        let at = now.addingTimeInterval(-hoursOld * 3600)
        if let u91 { prices.append(FuelPrice(fuel: "U91", price: u91, updatedAt: at)) }
        if let diesel { prices.append(FuelPrice(fuel: "Diesel", price: diesel, updatedAt: at)) }
        return Station(id: id, name: "\(brand) \(suburb)", brand: brand, address: "1 Test St", suburb: suburb,
                       state: "nsw", postcode: "2132", lat: -33.88, lng: 151.1, prices: prices, distance: km)
    }

    static func snapshot(_ date: String, _ avg: Double, fuel: String = "U91") -> Snapshot {
        Snapshot(date: date, fuel: fuel, min: avg - 10, avg: avg, max: avg + 10)
    }
}
