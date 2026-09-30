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
    /**
     * The brand family, resolved once here. Resolving means lowercasing the brand and scanning the
     * whole brand table, and rows, tags and filters read it for every station on every redraw.
     */
    let family: BrandFamily

    enum CodingKeys: String, CodingKey {
        case id, name, brand, address, suburb, state, postcode, lat, lng, prices, distance
    }

    init(id: String, name: String, brand: String, address: String, suburb: String, state: String,
         postcode: String, lat: Double, lng: Double, prices: [FuelPrice], distance: Double?) {
        self.id = id
        self.name = name
        self.brand = brand
        self.address = address
        self.suburb = suburb
        self.state = state
        self.postcode = postcode
        self.lat = lat
        self.lng = lng
        self.prices = prices
        self.distance = distance
        family = BrandFamily.resolve(brand)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), name: try c.decode(String.self, forKey: .name),
                  brand: try c.decode(String.self, forKey: .brand), address: try c.decode(String.self, forKey: .address),
                  suburb: try c.decode(String.self, forKey: .suburb), state: try c.decode(String.self, forKey: .state),
                  postcode: try c.decode(String.self, forKey: .postcode), lat: try c.decode(Double.self, forKey: .lat),
                  lng: try c.decode(Double.self, forKey: .lng), prices: try c.decode([FuelPrice].self, forKey: .prices),
                  distance: try c.decodeIfPresent(Double.self, forKey: .distance))
    }

    func price(_ fuel: FuelType) -> FuelPrice? { prices.first { $0.fuel == fuel.rawValue } }

    /**
     * How long a reported price counts as current. NSW stations report only when their price
     * changes, so a price several days old is usually still right; past a week the station may
     * have stopped reporting, and it is shown but not ranked.
     */
    static let currentFor: TimeInterval = 7 * 86_400

    /** Whether this station's price for `fuel` is recent enough to rank and to quote as cheapest. */
    func hasCurrentPrice(_ fuel: FuelType, now: Date = .now) -> Bool {
        guard let p = price(fuel) else { return false }
        return now.timeIntervalSince(p.updatedAt) <= Station.currentFor
    }

    /** Stand-in row for the loading state; redacted before it is shown. */
    static func placeholder(_ i: Int) -> Station {
        Station(id: "placeholder-\(i)", name: "Station name here", brand: "Independent", address: "", suburb: "Suburb",
                state: "nsw", postcode: "", lat: 0, lng: 0,
                prices: [FuelPrice(fuel: "U91", price: 229.9, updatedAt: .now)], distance: 4.2)
    }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}

/** Body shapes the car catalogue maps every model to (decision 0004); each has a stand-in picture (decision 0008). */
enum BodyType: String, CaseIterable, Codable, Sendable, Identifiable {
    case hatch, sedan, wagon, suv, ute, van
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hatch: "Hatch"
        case .sedan: "Sedan"
        case .wagon: "Wagon"
        case .suv: "SUV"
        case .ute: "Ute"
        case .van: "Van"
        }
    }
}

/** One model generation from the shared car catalogue (`/api/v1/vehicles`, `@servo-map/shared`). */
struct Vehicle: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let make: String
    let model: String
    let fromYear: Int
    let toYear: Int?
    let body: String
    let fuel: String
    let tankLitres: Int
    let source: String
    /** Site path of its picture (`vehicleImagePath` in @servo-map/shared); absent from older API responses. */
    var image: String? = nil

    var name: String { "\(make) \(model)" }
    /** "2017 on" while on sale, "2015–2023" once it ended; for captions. */
    var years: String { toYear.map { "\(fromYear)–\($0)" } ?? "\(fromYear) on" }
    /** "2017 – now" or "2015 – 2016": the generation as a choice in the add-a-car flow. */
    var yearRange: String { "\(fromYear) – \(toYear.map(String.init) ?? "now")" }
    var bodyType: BodyType { BodyType(rawValue: body) ?? .hatch }
    var fuelType: FuelType? { FuelType(rawValue: fuel) }
}

struct Snapshot: Codable, Hashable, Sendable {
    let date: String
    let fuel: String
    let min: Double
    let avg: Double
    let max: Double
    /** Stations that reported the fuel that day; absent from older cached payloads. */
    var stationCount: Int? = nil

    enum CodingKeys: String, CodingKey { case date, fuel, min, avg, max, stationCount = "station_count" }
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
