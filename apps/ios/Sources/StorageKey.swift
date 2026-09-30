import Foundation

/**
 * Every UserDefaults and `@AppStorage` key the app writes, named once. The raw values are what
 * existing installs already hold, so they never change.
 */
enum StorageKey {
    // Stations and searches
    static let saved = "saved"
    /** Each saved station's price when the Saved page was last opened, for its change. */
    static let savedLastSeen = "savedLastSeen"
    static let recentSearches = "recentSearches"

    // Read from the launch arguments' defaults domain (`-trendsPage cities`), never written.
    /** The Trends page to open on. */
    static let trendsPage = "trendsPage"
    /** The state Trends opens on. */
    static let trendsState = "trendsState"
    /** A development override of the API's base URL. */
    static let apiBase = "apiBase"

    // The car (MyCar writes these; CarSettings syncs them, decision 0004)
    static let carName = "carName"
    static let carVehicleID = "carVehicleID"
    /** The whole catalogue generation, so the car shows without a network call. */
    static let carVehicle = "carVehicle"
    static let carBody = "carBody"
    /** When the user started with this car, for "In this car". */
    static let carSince = "carSince"
    static let tankLitres = "tankLitres"
    static let catalogueTankLitres = "catalogueTankLitres"
    /** The car's fuel; the map opens on it unless `mapFuel` is set. */
    static let defaultFuel = "defaultFuel"

    // Alerts (synced as AlertPrefs)
    static let priceAlerts = "priceAlerts"
    static let alertCycleLow = "alertCycleLow"
    static let quietStart = "quietStart"
    static let quietEnd = "quietEnd"
    static let homeLat = "homeLat"
    static let homeLng = "homeLng"

    // Account and push
    static let account = "account"
    static let apnsToken = "apnsToken"

    // Settings on this device only
    /** The fuel the map opens on, picked in Settings › Map; empty follows the car. */
    static let mapFuel = "mapFuel"
    /** Radius in km that price tiers compare within (Settings › Map). */
    static let compareKm = "compareKm"
    static let showOldPrices = "showOldPrices"
    static let hideMembersOnly = "hideMembersOnly"
    static let directionsApp = "directionsApp"
    static let directionsAsk = "directionsAsk"
    static let appearance = "appearance"
}
