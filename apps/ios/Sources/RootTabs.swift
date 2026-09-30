import SwiftUI

/**
 * The app's navigation (decision 0008): the system tab bar in Liquid Glass with Nearby, Trends and
 * Settings, and Search in the search role, apart at the trailing end.
 *
 * The nearby results do not sit in a sheet under the bar, because a sheet is modal and always
 * covers the tab bar. The bar keeps the bottom edge; the cheapest station on the map rides above it
 * as the tab bar's bottom accessory (as Music's player does), and tapping it raises the full list
 * as a sheet with detents. The accessory shows on the Nearby tab only.
 */
struct RootTabs: View {
    private let route: LaunchRoute
    @State private var tab: AppTab
    @State private var showResults = false

    init(route: LaunchRoute) {
        self.route = route
        _tab = State(initialValue: route.tab)
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.nearby) {
                MapScreen(route: route, showResults: $showResults)
            } label: { label("Nearby", "fuelpump", .nearby) }
            Tab(value: AppTab.trends) {
                TrendsScreen()
            } label: { label("Trends", "chart.line.uptrend.xyaxis", .trends) }
            Tab(value: AppTab.settings) {
                SettingsScreen(page: route.settingsPage)
            } label: { label("Settings", "gearshape", .settings) }
            Tab(value: AppTab.search, role: .search) {
                SearchScreen()
            }
        }
        // As in Health: scrolling down folds the bar into one round button for the current tab.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: tab == .nearby) {
            NearbyAccessory { showResults = true }
        }
        .sensoryFeedback(.selection, trigger: tab)
    }

    /**
     * The owner kept the accent as ink, so colour cannot tell the selected tab apart: it takes the
     * filled symbol and the others the outline (and a bold title, set in Fonts).
     */
    private func label(_ title: String, _ symbol: String, _ value: AppTab) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol).environment(\.symbolVariants, tab == value ? .fill : .none)
        }
    }
}
