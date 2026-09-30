import Foundation
import Observation

/** One model in the add-a-car flow: every catalogue generation of a make and model, newest first. */
struct CarModel: Identifiable, Hashable, Sendable {
    let make: String
    let model: String
    /** Newest first; never empty. */
    let generations: [Vehicle]

    var id: String { "\(make)|\(model)" }
    var newest: Vehicle { generations[0] }
    var bodyType: BodyType { newest.bodyType }

    /** The Years step asks only when there is a choice; a single generation goes straight to Details. */
    var asksForYears: Bool { generations.count > 1 }

    /** "56", or "72–74" when the generations' tanks differ. */
    var tankLabel: String {
        let tanks = generations.map(\.tankLitres)
        let low = tanks.min() ?? 0, high = tanks.max() ?? 0
        return low == high ? "\(low)" : "\(low)–\(high)"
    }

    /** "2015 on" while any generation is on sale, otherwise "2018–2023", across every generation. */
    var years: String {
        let from = generations.map(\.fromYear).min() ?? newest.fromYear
        let ends = generations.map(\.toYear)
        guard !ends.contains(nil), let to = ends.compactMap({ $0 }).max() else { return "\(from) on" }
        return "\(from)–\(to)"
    }

    /** Groups catalogue generations by make and model: models by name, generations newest first. */
    static func group(_ vehicles: [Vehicle]) -> [CarModel] {
        Dictionary(grouping: vehicles) { "\($0.make)|\($0.model)" }.values
            .map { gens in
                let sorted = gens.sorted { $0.fromYear > $1.fromYear }
                return CarModel(make: sorted[0].make, model: sorted[0].model, generations: sorted)
            }
            .sorted { ($0.make, $0.model.lowercased()) < ($1.make, $1.model.lowercased()) }
    }
}

/** A make in the catalogue and its models. */
struct CarMake: Identifiable, Hashable, Sendable {
    let name: String
    let models: [CarModel]
    var id: String { name }

    /** Bodies these models come in with how many of each, most first; the Model step's filter. */
    var bodies: [(body: BodyType, count: Int)] {
        let counts = Dictionary(grouping: models, by: \.bodyType).mapValues(\.count)
        return BodyType.allCases.compactMap { body in counts[body].map { (body, $0) } }
            .sorted { $0.count > $1.count }
    }

    /**
     * The make as a file name, e.g. "land-rover": its mark is the asset `car-{slug}`. Mirrors
     * `makeSlug` in @servo-map/shared, which names the files in design/car-logos.
     */
    static func slug(_ make: String) -> String {
        make.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /** Up to three capitals for a make without a mark: "MG", "BYD", "HOL" for Holden. */
    static func monogram(_ make: String) -> String {
        let letters = make.filter(\.isLetter)
        let words = make.split(whereSeparator: { $0 == " " || $0 == "-" })
        if words.count > 1 { return String(words.prefix(3).compactMap(\.first)).uppercased() }
        return String(letters.prefix(3)).uppercased()
    }

    /** Groups catalogue generations into makes, alphabetical. */
    static func group(_ vehicles: [Vehicle]) -> [CarMake] {
        Dictionary(grouping: CarModel.group(vehicles), by: \.make)
            .map { CarMake(name: $0.key, models: $0.value) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /**
     * The makes with the most models in the catalogue, which was drawn from Australia's best
     * sellers; ties keep alphabetical order.
     */
    static func mostCommon(_ makes: [CarMake], count: Int = 9) -> [CarMake] {
        Array(makes.enumerated().sorted { a, b in
            a.element.models.count != b.element.models.count ? a.element.models.count > b.element.models.count : a.offset < b.offset
        }.map(\.element).prefix(count))
    }
}

extension Vehicle {
    /** Site path of the picture: the API's when it sent one, else the same rule from @servo-map/shared. */
    var imagePath: String { image ?? VehicleImage.path(id: id, body: body) }

    /** Where the tank size was read, as a short host: "carsguide.com.au". */
    var sourceHost: String? {
        URL(string: source)?.host(percentEncoded: false).map { $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0 }
    }
}

/**
 * The car catalogue for the add-a-car flow, loaded make by make from `/api/v1/vehicles` (which
 * returns at most 100 generations a request) and kept for the session.
 */
@MainActor @Observable
final class VehicleCatalogue {
    enum Phase: Equatable { case idle, loading, loaded, failed }

    private(set) var phase = Phase.idle
    private(set) var makes: [CarMake] = []

    init() {}

    /** A catalogue that is already loaded, for tests and previews. */
    init(vehicles: [Vehicle]) {
        makes = CarMake.group(vehicles)
        phase = .loaded
    }

    /** The fetch in flight, shared by every caller; a caller's cancellation does not cancel it. */
    private var inFlight: Task<Void, Never>?

    /** Loads the catalogue once; callers arriving while it loads wait for the same fetch. */
    func load() async {
        if phase == .loaded { return }
        if let inFlight { await inFlight.value; return }
        let task = Task { await fetch() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func fetch() async {
        phase = .loading
        do {
            let names = try await API().vehicleMakes()
            let vehicles = try await withThrowingTaskGroup(of: [Vehicle].self) { group in
                for name in names {
                    // Search matches words anywhere in make and model; keep the make's own rows.
                    group.addTask { try await API().vehicles(name, limit: 100).filter { $0.make == name } }
                }
                var all: [Vehicle] = []
                for try await part in group { all += part }
                return all
            }
            makes = CarMake.group(vehicles)
            phase = .loaded
        } catch {
            phase = .failed
        }
    }

    func make(_ name: String) -> CarMake? { makes.first { $0.name == name } }

    func model(of vehicle: Vehicle) -> CarModel? {
        make(vehicle.make)?.models.first { $0.model == vehicle.model }
    }

    func vehicle(id: String) -> Vehicle? {
        for make in makes {
            for model in make.models { if let v = model.generations.first(where: { $0.id == id }) { return v } }
        }
        return nil
    }
}
