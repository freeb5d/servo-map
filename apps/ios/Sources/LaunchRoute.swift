import Foundation

/** The app's tabs, in the order the tab bar shows them; Search sits apart in the search role. */
enum AppTab: String, Hashable, CaseIterable {
    case nearby = "map", trends, settings, search
}

/**
 * What launch arguments open, so design screenshots are reproducible:
 * `-tab map|trends|settings|search`; `-tab you` opens the You sheet, and `-tab saved|log|car|alerts|sources`
 * opens it on that page; `-settings directions|map|alerts|appearance|data|account|sources|car` opens
 * a Settings page (and the Settings tab); `-filters`; `-detail` opens the cheapest station;
 * `-widgets` shows the widget gallery.
 */
struct LaunchRoute: Equatable {
    var tab: AppTab = .nearby
    var openYou = false
    var youPage: YouScreen.Page?
    var settingsPage: SettingsPage?
    var openFilters = false
    var openDetail = false
    var widgets = false

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
            return arguments[i + 1]
        }
        let tabName = value(after: "-tab") ?? AppTab.nearby.rawValue
        // Saved and Log live in the You sheet, which opens over the map.
        youPage = YouScreen.Page.allCases.first { "\($0)" == tabName }
        openYou = tabName == "you" || youPage != nil
        tab = openYou ? .nearby : AppTab(rawValue: tabName) ?? .nearby
        settingsPage = value(after: "-settings").flatMap(SettingsPage.init(rawValue:))
        if settingsPage != nil { tab = .settings }
        openFilters = arguments.contains("-filters")
        openDetail = arguments.contains("-detail")
        widgets = arguments.contains("-widgets")
    }
}
