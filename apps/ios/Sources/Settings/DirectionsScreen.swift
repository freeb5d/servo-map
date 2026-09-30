import SwiftUI
import UIKit

/** Settings › Directions: which installed app opens when you tap Directions, or ask each time. */
struct DirectionsScreen: View {
    @AppStorage(StorageKey.directionsApp) private var preferred = NavApp.apple.rawValue
    @AppStorage(StorageKey.directionsAsk) private var ask = false
    @State private var offered = DirectionsLauncher.device.offered

    var body: some View {
        PlainPage(intro: "The app that opens when you tap Directions on a station.") {
            PlainGroup(footer: "Only apps on this iPhone are listed. Apple Maps is always available.", inset: 0) {
                ForEach(offered) { app in
                    PlainChoiceRow(title: app.name, subtitle: app == .apple ? "Built in" : "Installed",
                                   selected: chosen == app) {
                        preferred = app.rawValue
                    } leading: {
                        NavAppIcon(app: app)
                    }
                }
            }
            PlainGroup(title: "Choosing", inset: 0) {
                PlainToggleRow(title: "Ask each time", subtitle: "Pick the app when you tap Directions", isOn: $ask)
            }
        }
        // An app installed or removed while ServoMap was in the background.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            offered = DirectionsLauncher.device.offered
        }
    }

    /** The stored choice while it is still installed; otherwise Apple Maps, which directions fall back to. */
    private var chosen: NavApp {
        NavApp(rawValue: preferred).flatMap { offered.contains($0) ? $0 : nil } ?? .apple
    }
}

/**
 * The app's own App Store icon (design/nav-app-icons), in the iOS icon shape, so the row names the
 * app a link opens. The corner is the home screen's squircle, 22.37 % of the edge, not a 素 radius.
 */
struct NavAppIcon: View {
    let app: NavApp
    var size: CGFloat = 36

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
        Image(app.iconAsset)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(shape.strokeBorder(ServoMapColor.line, lineWidth: ServoMapList.hairline))
            .accessibilityHidden(true)
            // A mark, not reading text: it keeps its size at every Dynamic Type setting.
            .dynamicTypeSize(...DynamicTypeSize.large)
    }
}
