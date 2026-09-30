import SwiftUI

@main
struct ServoMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Opens on the fuel, members-only choice and tier radius from Settings › Map.
    @State private var store = MapPreferences.launchStore()
    @State private var log = FillUpLog()
    @State private var account = AccountStore()
    @AppStorage(StorageKey.appearance) private var appearance = Appearance.system.rawValue
    // Launch arguments open a given screen, so design screenshots are reproducible (see LaunchRoute).
    private let route = LaunchRoute(arguments: ProcessInfo.processInfo.arguments)

    init() {
        Fonts.register()
        Fonts.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if route.widgets {
                    WidgetGallery()
                } else {
                    RootTabs(route: route).modifier(AccountSync())
                }
            }
                .environment(store)
                .environment(log)
                .environment(account)
                .tint(ServoMapColor.accent)
                .font(ServoMapFont.body(.footnote))
                // Paper or Ink from Settings › Appearance; System follows the iPhone.
                .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
                .task {
                    await store.load()
                    await account.refresh(store: store, log: log)
                }
        }
    }
}

/**
 * Pushes each local change to the signed-in account as it happens: saved stations, fill-ups added
 * or removed, the car and alert settings (after a short pause, so a Stepper does not send ten
 * requests), and the device's push token.
 */
private struct AccountSync: ViewModifier {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(AccountStore.self) private var account
    @AppStorage(StorageKey.carName) private var carName = "My car"
    @AppStorage(StorageKey.carVehicleID) private var carVehicleID = ""
    @AppStorage(StorageKey.carBody) private var carBody = ""
    @AppStorage(StorageKey.tankLitres) private var tankLitres = 50
    @AppStorage(StorageKey.defaultFuel) private var defaultFuel = ""
    @AppStorage(StorageKey.priceAlerts) private var priceAlerts = false
    @AppStorage(StorageKey.alertCycleLow) private var cycleLow = false
    @AppStorage(StorageKey.quietStart) private var quietStart = 22
    @AppStorage(StorageKey.quietEnd) private var quietEnd = 7
    @AppStorage(StorageKey.apnsToken) private var apnsToken = ""
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onChange(of: store.savedIDs) { _, ids in Task { await account.pushSaved(ids) } }
            .onChange(of: log.entries) { old, new in
                let before = Set(old.map(\.id)), after = Set(new.map(\.id))
                let added = new.filter { !before.contains($0.id) }
                let removed = before.subtracting(after)
                Task {
                    if !added.isEmpty { await account.pushFillUps(added) }
                    for id in removed { await account.pushDeletedFillUp(id) }
                }
            }
            .onChange(of: "\(carName)|\(carVehicleID)|\(carBody)|\(tankLitres)|\(defaultFuel)") { debounce { await account.pushCar() } }
            .onChange(of: "\(priceAlerts)|\(cycleLow)|\(quietStart)|\(quietEnd)") {
                // "Near home" is where the user last located themselves, rounded to ~1 km on the server.
                if cycleLow, let here = store.userLocation { AlertPrefs.setHome(lat: here.lat, lng: here.lng) }
                debounce { await account.pushAlerts() }
            }
            .onChange(of: apnsToken) { _, token in if !token.isEmpty { Task { await account.pushDevice(token) } } }
            .onChange(of: account.status) { _, status in
                if status == .signedIn, !apnsToken.isEmpty { Task { await account.pushDevice(apnsToken) } }
            }
    }

    private func debounce(_ work: @escaping @MainActor () async -> Void) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await work()
        }
    }
}
