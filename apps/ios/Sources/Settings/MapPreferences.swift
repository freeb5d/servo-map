import Foundation

/** What Settings › Map stores, and how it reaches the Store when the app opens. */
@MainActor
enum MapPreferences {
    /** The radii "Compare within" offers, in km. */
    nonisolated static let compareChoices = [2, 5, 10, 20, 50]
    /**
     * 20 km, the first fetch's radius: before this setting, tiers compared every station fetched,
     * so the default keeps the map's colours as they were.
     */
    nonisolated static let defaultCompareKm = 20

    /** The fuel the map opens on: the one picked in Settings, else the car's, else U91. */
    static func launchFuel(_ d: UserDefaults = .standard) -> FuelType {
        d.string(forKey: StorageKey.mapFuel).flatMap(FuelType.init(rawValue:))
            ?? d.string(forKey: StorageKey.defaultFuel).flatMap(FuelType.init(rawValue:))
            ?? .u91
    }

    /** The stored radius, or the default when none (or one no longer offered) is stored. */
    static func compareKm(_ d: UserDefaults = .standard) -> Int {
        let stored = d.integer(forKey: StorageKey.compareKm)
        return compareChoices.contains(stored) ? stored : defaultCompareKm
    }

    static func launchStore(_ d: UserDefaults = .standard) -> Store {
        let store = Store(fuel: launchFuel(d))
        store.compareKm = compareKm(d)
        store.filters.hideMembersOnly = d.bool(forKey: StorageKey.hideMembersOnly)
        return store
    }
}
