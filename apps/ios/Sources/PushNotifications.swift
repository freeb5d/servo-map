import SwiftUI
import UIKit
import UserNotifications

/** Where the APNs device token is kept until a server can send price alerts to it. */
enum PushToken {
    static let key = "apnsToken"

    /** APNs tokens are raw bytes; servers expect them as lowercase hex. */
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}

/**
 * Receives the APNs registration result. Price alerts have no sending server yet, so the token
 * stays on the device (see /privacy) until one exists.
 */
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        UserDefaults.standard.set(PushToken.hex(deviceToken), forKey: PushToken.key)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The simulator and unsigned builds cannot register; alerts simply stay off there.
        UserDefaults.standard.removeObject(forKey: PushToken.key)
        print("APNs registration failed: \(error.localizedDescription)")
    }
}

/** Turning price alerts on: ask once for permission, then register with APNs. */
@MainActor
enum PriceAlerts {
    /** Returns whether alerts are allowed; the caller turns its switch back off when not. */
    static func enable() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }
}

/** The switch on the Saved screen. Price-drop alerts for saved stations arrive once the server sends them. */
struct PriceAlertsSection: View {
    @AppStorage("priceAlerts") private var on = false
    @State private var denied = false

    var body: some View {
        Section {
            Toggle("Price drop alerts", isOn: $on)
                .paperRow()
                .onChange(of: on) {
                    guard on else { return }
                    Task {
                        let allowed = await PriceAlerts.enable()
                        denied = !allowed
                        if !allowed { on = false }
                    }
                }
        } footer: {
            Text(denied
                 ? "Notifications are off for ServoMap. Turn them on in Settings to get alerts."
                 : "A notification when one of your saved stations drops its price.")
        }
    }
}
