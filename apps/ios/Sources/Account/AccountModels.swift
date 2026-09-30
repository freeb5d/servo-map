import Foundation

// Wire types for /api/v1/auth and /api/v1/me. They mirror packages/shared/src/account.ts, which
// owns the contract (docs/openapi.yaml documents it); change both together.

struct AccountDTO: Codable, Equatable, Sendable {
    let id: String
    let provider: String
    let email: String?
    let name: String?
    /** Profile photo URL from Google; Apple sends none. */
    let picture: String?
    let createdAt: String
}

struct SessionDTO: Codable, Sendable {
    let token: String
    let account: AccountDTO
}

struct FillUpDTO: Codable, Equatable, Sendable {
    let id: String
    let date: String
    let stationId: String
    let stationName: String
    let brand: String
    let fuel: String
    let litres: Double
    let centsPerLitre: Double
    let areaAverage: Double?
}

struct CarDTO: Codable, Equatable, Sendable {
    var vehicleId: String?
    var name: String
    var body: String
    var paint: String
    var fuel: String
    var tankLitres: Int
    var catalogueTankLitres: Int?
}

struct AlertsDTO: Codable, Equatable, Sendable {
    struct Home: Codable, Equatable, Sendable { let lat: Double; let lng: Double }
    var priceDrop: Bool
    var cycleLow: Bool
    var quietStart: Int
    var quietEnd: Int
    var home: Home?
}

struct MeDTO: Codable, Sendable {
    let account: AccountDTO
    let savedStationIds: [String]
    let fillUps: [FillUpDTO]
    let car: CarDTO?
    let alerts: AlertsDTO
}

extension FillUp {
    /** A new formatter per use: ISO8601DateFormatter is not Sendable, and this runs rarely. */
    private static var iso: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    var dto: FillUpDTO {
        FillUpDTO(id: id.uuidString, date: Self.iso.string(from: date), stationId: stationID, stationName: stationName,
                  brand: brand, fuel: fuel.rawValue, litres: litres, centsPerLitre: centsPerLitre, areaAverage: areaAverage)
    }

    init?(_ dto: FillUpDTO) {
        guard let id = UUID(uuidString: dto.id), let date = Self.iso.date(from: dto.date), let fuel = FuelType(rawValue: dto.fuel) else { return nil }
        self.init(id: id, date: date, stationID: dto.stationId, stationName: dto.stationName, brand: dto.brand,
                  fuel: fuel, litres: dto.litres, centsPerLitre: dto.centsPerLitre, areaAverage: dto.areaAverage)
    }
}
