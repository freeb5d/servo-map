import SwiftUI

@main
struct ServoMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Opens on the fuel from the car profile (MyCar writes "defaultFuel").
    @State private var store = Store(fuel: FuelType(rawValue: UserDefaults.standard.string(forKey: "defaultFuel") ?? "") ?? .u91)
    @State private var log = FillUpLog()
    @State private var account = AccountStore()
    // Launch arguments open a given screen, so design screenshots are reproducible:
    // -tab map|trends|search, you to open the You sheet, or saved|log|car|alerts|sources for one of its pages, -filters, -detail (opens the cheapest station), -widgets.
    // With -tab you: -addCar make|model|years|details [-addCarModel Make/Model] opens the add-a-car flow on that step.
    private let args = ProcessInfo.processInfo.arguments

    init() {
        Fonts.register()
        Fonts.styleNavigationBars()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if args.contains("-widgets") {
                    WidgetGallery()
                } else {
                    RootView(initialTab: value(after: "-tab") ?? "map", openFilters: args.contains("-filters"), openDetail: args.contains("-detail"))
                }
            }
                .environment(store)
                .environment(log)
                .environment(account)
                .tint(ServoMapColor.accent)
                .font(ServoMapFont.body(.footnote))
                .task {
                    await store.load()
                    await account.refresh(store: store, log: log)
                }
        }
    }

    private func value(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

struct RootView: View {
    let initialTab: String
    let openFilters: Bool
    let openDetail: Bool

    var body: some View {
        MapScreen(tab: initialTab, openFilters: openFilters, openDetail: openDetail)
            .modifier(AccountSync())
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
    @AppStorage("carName") private var carName = "My car"
    @AppStorage("carVehicleID") private var carVehicleID = ""
    @AppStorage("carBody") private var carBody = ""
    @AppStorage("tankLitres") private var tankLitres = 50
    @AppStorage("defaultFuel") private var defaultFuel = ""
    @AppStorage("priceAlerts") private var priceAlerts = false
    @AppStorage("alertCycleLow") private var cycleLow = false
    @AppStorage("quietStart") private var quietStart = 22
    @AppStorage("quietEnd") private var quietEnd = 7
    @AppStorage("apnsToken") private var apnsToken = ""
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
                if cycleLow, let here = store.userLocation {
                    UserDefaults.standard.set(here.lat, forKey: "homeLat")
                    UserDefaults.standard.set(here.lng, forKey: "homeLng")
                }
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
