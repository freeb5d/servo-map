import SwiftUI

/** The user's car as the pages show it, read from what `MyCar` stores. */
struct StoredCar: Equatable {
    var vehicleID: String
    /** The catalogue generation; nil for a car entered by hand, or until a synced id is looked up. */
    var vehicle: Vehicle?
    var name: String
    var body: BodyType
    var fuel: FuelType
    var tankLitres: Int
    var catalogueTankLitres: Int
    var since: Date?

    /** Whether the user has set up a car at all. */
    var exists: Bool { !vehicleID.isEmpty || name != MyCar.defaultName }
    /** "Mazda CX-5", or the user's name for a car entered by hand. */
    var title: String { vehicle?.name ?? name }
    var make: String? { vehicle?.make }
    /** "2017 on · SUV", or the body type alone for a car entered by hand. */
    var caption: String { vehicle.map { "\($0.years) · \($0.bodyType.label)" } ?? body.label }
    /** The user's own name, when the car also has a make and model to go by. */
    var nickname: String? { vehicle == nil ? nil : MyCar.nickname(name, vehicle: vehicle) }
    var imagePath: String { vehicle?.imagePath ?? VehicleImage.path(id: vehicleID.isEmpty ? nil : vehicleID, body: body.rawValue) }
    /** Whether the tank is the catalogue's figure rather than the user's. */
    var tankFromCatalogue: Bool { catalogueTankLitres > 0 && catalogueTankLitres == tankLitres }
}

/**
 * Hands its content the stored car, kept current as it changes. A vehicle id synced from another
 * device arrives without its generation; this looks it up in the catalogue once and keeps it.
 */
struct WithStoredCar<Content: View>: View {
    @ViewBuilder let content: (StoredCar) -> Content
    @Environment(VehicleCatalogue.self) private var catalogue
    @AppStorage(MyCar.Key.vehicleID) private var vehicleID = ""
    @AppStorage(MyCar.Key.vehicle) private var vehicleData: Data?
    @AppStorage(MyCar.Key.name) private var name = MyCar.defaultName
    @AppStorage(MyCar.Key.body) private var bodyType = BodyType.hatch.rawValue
    @AppStorage(MyCar.Key.fuel) private var fuel = FuelType.u91.rawValue
    @AppStorage(MyCar.Key.tank) private var tank = 50
    @AppStorage(MyCar.Key.catalogueTank) private var catalogueTank = 0
    @AppStorage(MyCar.Key.since) private var since = 0.0

    var body: some View {
        content(car)
            .task(id: vehicleID) {
                guard !vehicleID.isEmpty, car.vehicle == nil else { return }
                await catalogue.load()
                if let found = catalogue.vehicle(id: vehicleID) { MyCar.adopt(found) }
            }
    }

    private var car: StoredCar {
        StoredCar(vehicleID: vehicleID, vehicle: MyCar.decode(vehicleData), name: name,
                  body: BodyType(rawValue: bodyType) ?? .hatch, fuel: FuelType(rawValue: fuel) ?? .u91,
                  tankLitres: tank, catalogueTankLitres: catalogueTank,
                  since: since > 0 ? Date(timeIntervalSince1970: since) : nil)
    }
}
