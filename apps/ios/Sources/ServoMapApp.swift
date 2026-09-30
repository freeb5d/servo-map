import SwiftUI

@main
struct ServoMapApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // Opens on the fuel from the car profile (CarForm writes "defaultFuel").
    @State private var store = Store(fuel: FuelType(rawValue: UserDefaults.standard.string(forKey: "defaultFuel") ?? "") ?? .u91)
    @State private var log = FillUpLog()
    // Launch arguments open a given screen, so design screenshots are reproducible:
    // -tab map|trends|search, you to open the You sheet, or saved|log|car|alerts for one of its pages, -filters, -detail (opens the cheapest station), -widgets.
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
                .tint(ServoMapColor.accent)
                .font(ServoMapFont.body(.footnote))
                .task { await store.load() }
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
    }
}
