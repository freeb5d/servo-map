import Foundation

/**
 * The user's car as kept on this device. The keys are the ones `CarSettings` syncs to the
 * account; `carVehicle` keeps the whole catalogue generation (years, source, picture) so the car
 * shows without a network call, and `carSince` dates "In this car".
 */
enum MyCar {
    enum Key {
        static let name = "carName"
        static let vehicleID = "carVehicleID"
        static let vehicle = "carVehicle"
        static let body = "carBody"
        static let tank = "tankLitres"
        static let catalogueTank = "catalogueTankLitres"
        static let fuel = "defaultFuel"
        static let since = "carSince"
    }

    /** The name before the user gives one; not shown as a nickname. */
    static let defaultName = "My car"

    private static var d: UserDefaults { .standard }

    /** The stored catalogue generation, when it matches the stored vehicle id. */
    static var vehicle: Vehicle? { decode(d.data(forKey: Key.vehicle)) }

    static func decode(_ data: Data?) -> Vehicle? {
        guard let data, let v = try? JSONDecoder().decode(Vehicle.self, from: data) else { return nil }
        return v.id == (d.string(forKey: Key.vehicleID) ?? "") ? v : nil
    }

    /** Keeps the generation a synced vehicle id points at, once the catalogue has found it. */
    static func adopt(_ vehicle: Vehicle) {
        guard vehicle.id == d.string(forKey: Key.vehicleID) else { return }
        d.set(try? JSONEncoder().encode(vehicle), forKey: Key.vehicle)
    }

    /**
     * Saves the car from the add-a-car flow: a catalogue generation, or a car entered by hand
     * (`vehicle` nil) with its body type. The map switches to the car's fuel.
     */
    @MainActor
    static func save(vehicle: Vehicle?, name: String, body: BodyType, fuel: FuelType, tankLitres: Int, store: Store, now: Date = .now) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let changedCar = (vehicle?.id ?? "") != (d.string(forKey: Key.vehicleID) ?? "") || d.object(forKey: Key.since) == nil
        d.set(vehicle?.id ?? "", forKey: Key.vehicleID)
        d.set(vehicle.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.vehicle)
        // The server needs a name; with none given the car goes by its make and model.
        d.set(trimmed.isEmpty ? (vehicle?.name ?? defaultName) : trimmed, forKey: Key.name)
        d.set(vehicle?.body ?? body.rawValue, forKey: Key.body)
        d.set(tankLitres, forKey: Key.tank)
        d.set(vehicle?.tankLitres ?? 0, forKey: Key.catalogueTank)
        d.set(fuel.rawValue, forKey: Key.fuel)
        if changedCar { d.set(now.timeIntervalSince1970, forKey: Key.since) }
        store.fuel = fuel
    }

    /** The user's own name for the car, when it is more than its make and model. */
    static func nickname(_ name: String, vehicle: Vehicle?) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != defaultName, trimmed != vehicle?.name else { return nil }
        return trimmed
    }
}
