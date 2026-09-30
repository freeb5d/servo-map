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

    /**
     * `count` stations scattered over about 100 x 75 km of Sydney (-34.3 to -33.4, 150.6 to
     * 151.4), with prices from 180 to 260; the same field every run.
     */
    static func field(_ count: Int) -> [Station] {
        var seed: UInt64 = 42
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(UInt64(1) << 53)
        }
        let brands = ["BP", "Shell", "Metro Fuel", "EG Ampol", "7-Eleven"]
        return (0..<count).map { i in
            let lat = -34.3 + next() * 0.9, lng = 150.6 + next() * 0.8, price = 180 + next() * 80
            return Station(id: "s\(i)", name: "Station \(i)", brand: brands[i % brands.count], address: "", suburb: "Suburb",
                           state: "nsw", postcode: "2000", lat: lat, lng: lng,
                           prices: [FuelPrice(fuel: "U91", price: price, updatedAt: now.addingTimeInterval(-3600))],
                           distance: next() * 50)
        }
    }

    static func snapshot(_ date: String, _ avg: Double, fuel: String = "U91") -> Snapshot {
        Snapshot(date: date, fuel: fuel, min: avg - 10, avg: avg, max: avg + 10)
    }
}
