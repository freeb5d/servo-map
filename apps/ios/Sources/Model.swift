import CoreLocation
import Foundation

enum FuelType: String, CaseIterable, Identifiable, Codable, Sendable {
    case u91 = "U91", e10 = "E10", u95 = "U95", u98 = "U98", diesel = "Diesel"
    var id: String { rawValue }
}

struct FuelPrice: Codable, Hashable, Sendable {
    let fuel: String
    /** Cents per litre. */
    let price: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey { case fuel, price, updatedAt = "updated_at" }
}

struct Station: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let brand: String
    let address: String
    let suburb: String
    let state: String
    let postcode: String
    let lat: Double
    let lng: Double
    let prices: [FuelPrice]
    let distance: Double?

    func price(_ fuel: FuelType) -> FuelPrice? { prices.first { $0.fuel == fuel.rawValue } }

    /** Stand-in row for the loading state; redacted before it is shown. */
    static func placeholder(_ i: Int) -> Station {
        Station(id: "placeholder-\(i)", name: "Station name here", brand: "Independent", address: "", suburb: "Suburb",
                state: "nsw", postcode: "", lat: 0, lng: 0,
                prices: [FuelPrice(fuel: "U91", price: 229.9, updatedAt: .now)], distance: 4.2)
    }
    var family: BrandFamily { BrandFamily.resolve(brand) }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}

struct Snapshot: Codable, Hashable, Sendable {
    let date: String
    let fuel: String
    let min: Double
    let avg: Double
    let max: Double
}

enum PriceTier: String, Sendable {
    case cheap = "Cheap", fair = "Fair", pricey = "Pricey"
}

/** Cheapest third / middle third / dearest third of the prices in view, as on the web. */
struct PriceRange: Sendable {
    let cheapBelow: Double
    let midBelow: Double

    init(_ prices: [Double]) {
        let sorted = prices.sorted()
        cheapBelow = sorted.isEmpty ? 0 : sorted[Int(Double(sorted.count) * 0.33)]
        midBelow = sorted.isEmpty ? 0 : sorted[Swift.min(sorted.count - 1, Int(Double(sorted.count) * 0.66))]
    }

    func tier(_ price: Double) -> PriceTier {
        price <= cheapBelow ? .cheap : price <= midBelow ? .fair : .pricey
    }
}
