import SwiftUI

/** The pages Settings opens; the raw value is the name `-settings` takes at launch. */
enum SettingsPage: String, Hashable, CaseIterable {
    case account, car, directions, map, alerts, appearance, data, sources

    var title: String {
        switch self {
        case .account: "Account"
        case .car: "Car"
        case .directions: "Directions"
        case .map: "Map"
        case .alerts: "Alerts"
        case .appearance: "Appearance"
        case .data: "Your data"
        case .sources: "Data sources"
        }
    }
}

/**
 * The Settings tab (decision 0008): who you are, then Driving, App and About as 素 plain lists.
 * Each row shows its current value and opens a second-level page.
 */
struct SettingsScreen: View {
    @Environment(Store.self) private var store
    @Environment(AccountStore.self) private var account
    @State private var path: [SettingsPage]
    /** The car catalogue the Car page and its add-a-car flow read, as in You. */
    @State private var catalogue = VehicleCatalogue()
    @AppStorage(StorageKey.carName) private var carName = MyCar.defaultName
    @AppStorage(StorageKey.carVehicleID) private var carVehicleID = ""
    @AppStorage(StorageKey.directionsApp) private var directionsApp = NavApp.apple.rawValue
    @AppStorage(StorageKey.directionsAsk) private var directionsAsk = false
    @AppStorage(StorageKey.priceAlerts) private var priceAlerts = false
    @AppStorage(StorageKey.alertCycleLow) private var cycleLow = false
    @AppStorage(StorageKey.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(StorageKey.compareKm) private var compareKm = MapPreferences.defaultCompareKm

    /** Opens on the root, or straight onto `page` (launch arguments). */
    init(page: SettingsPage? = nil) {
        _path = State(initialValue: page.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            PlainPage {
                AccountHeader()
                PlainGroup(title: "Driving") {
                    link(.car, icon: "car", value: carVehicleID.isEmpty && carName == MyCar.defaultName ? "Not set" : carName)
                    link(.directions, icon: "arrow.triangle.turn.up.right.diamond", value: directionsValue)
                    link(.map, icon: "map", value: "\(store.fuel.rawValue) · \(compareKm) km")
                }
                PlainGroup(title: "App") {
                    link(.alerts, icon: "bell", value: alertsValue)
                    link(.appearance, icon: "circle.lefthalf.filled", value: (Appearance(rawValue: appearance) ?? .system).title)
                    link(.data, icon: "square.and.arrow.down", value: "Export, delete")
                }
                PlainGroup(title: "About") {
                    link(.sources, icon: "info.circle", value: sourcesValue)
                    PlainRow(icon: "gauge.with.needle", title: "Version", value: Self.version, chevron: false)
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsPage.self) { page in
                // Your car titles itself with the car, as it does from You.
                if page == .car { CarPage() } else { destination(page).navigationTitle(page.title) }
            }
        }
        .environment(catalogue)
    }

    @ViewBuilder private func destination(_ page: SettingsPage) -> some View {
        switch page {
        case .account: AccountScreen()
        case .car: CarPage()
        case .directions: DirectionsScreen()
        case .map: MapSettingsScreen()
        case .alerts: AlertsScreen()
        case .appearance: AppearanceScreen()
        case .data: YourDataScreen()
        case .sources: DataSourcesScreen()
        }
    }

    private func link(_ page: SettingsPage, icon: String, value: String) -> some View {
        NavigationLink(value: page) {
            PlainRow(icon: icon, title: page.title, value: value)
        }
        .buttonStyle(.plainRow)
    }

    private var directionsValue: String {
        if directionsAsk { return "Ask each time" }
        let app = NavApp(rawValue: directionsApp) ?? .apple
        return DirectionsLauncher.device.offered.contains(app) ? app.name : NavApp.apple.name
    }

    private var alertsValue: String {
        let on = [priceAlerts, cycleLow].filter { $0 }.count
        return on == 0 ? "Off" : "\(on) on"
    }

    private var sourcesValue: String {
        let n = store.liveStates.count
        return n == 0 ? "" : n == 1 ? "1 state" : "\(n) states"
    }

    /** "0.5.0 (6)": the marketing version and the build, from the bundle. */
    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
