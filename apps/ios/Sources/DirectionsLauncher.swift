import MapKit
import SwiftUI
import UIKit

/** An app that can give driving directions to a station. */
enum NavApp: String, CaseIterable, Identifiable, Sendable {
    case apple, google, waze

    var id: String { rawValue }

    var name: String {
        switch self {
        case .apple: "Apple Maps"
        case .google: "Google Maps"
        case .waze: "Waze"
        }
    }

    /** The App Store icon in the asset catalog (design/nav-app-icons), shown only to name the app. */
    var iconAsset: String { "nav-\(rawValue)" }

    /** The scheme that tells whether the app is installed; Apple Maps is always there. */
    var probe: URL? {
        switch self {
        case .apple: nil
        case .google: URL(string: "comgooglemaps://")
        case .waze: URL(string: "waze://")
        }
    }
}

/**
 * The one place directions are opened from (Settings › Directions decides which app). Apple Maps
 * is always offered; Google Maps and Waze only when installed, which needs their schemes in
 * `LSApplicationQueriesSchemes` (project.yml).
 */
struct DirectionsLauncher {
    struct Destination: Hashable, Identifiable, Sendable {
        var lat: Double
        var lng: Double
        var name: String?
        var id: String { "\(lat),\(lng)" }
    }

    /**
     * How an app is opened. Apple Maps takes a named map item, so the station's name shows as the
     * destination. Google Maps and Waze take a URL; their schemes have no label for coordinates,
     * and passing the name as the destination would make them search for it instead.
     */
    enum Launch: Equatable {
        case appleMaps(Destination)
        case url(URL)
    }

    /** Whether to open an app straight away or let the reader pick one. */
    enum Decision: Equatable {
        case open(NavApp)
        case ask([NavApp])
    }

    /** Answers whether a URL's app is installed; `UIApplication.canOpenURL` outside tests. */
    let canOpen: (URL) -> Bool

    /** The apps to offer: Apple Maps, then any other that is installed. */
    var offered: [NavApp] {
        NavApp.allCases.filter { app in app.probe.map(canOpen) ?? true }
    }

    /**
     * The chosen app when it is still installed, else Apple Maps. Asking only makes sense with
     * more than one app to pick from.
     */
    func decide(preferred: NavApp?, ask: Bool) -> Decision {
        let apps = offered
        if ask, apps.count > 1 { return .ask(apps) }
        if let preferred, apps.contains(preferred) { return .open(preferred) }
        return .open(.apple)
    }

    static func launch(_ app: NavApp, to destination: Destination) -> Launch {
        let ll = "\(coordinate(destination.lat)),\(coordinate(destination.lng))"
        switch app {
        case .apple:
            return .appleMaps(destination)
        case .google:
            return .url(URL(string: "comgooglemaps://?daddr=\(ll)&directionsmode=driving")!)
        case .waze:
            return .url(URL(string: "waze://?ll=\(ll)&navigate=yes")!)
        }
    }

    /** Six decimals (about 10 cm), always with a full stop whatever the reader's locale. */
    private static func coordinate(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    @MainActor
    static func open(_ launch: Launch, openURL: OpenURLAction) {
        switch launch {
        case .appleMaps(let destination):
            let item = MKMapItem(location: CLLocation(latitude: destination.lat, longitude: destination.lng), address: nil)
            item.name = destination.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        case .url(let url):
            openURL(url)
        }
    }

    /** The launcher for this iPhone. */
    @MainActor
    static var device: DirectionsLauncher {
        DirectionsLauncher { UIApplication.shared.canOpenURL($0) }
    }
}

extension DirectionsLauncher.Destination {
    init(_ station: Station) {
        self.init(lat: station.lat, lng: station.lng, name: station.name)
    }
}

/**
 * Opens directions to `destination` once it is set: straight into the chosen app, or through a
 * confirmation dialog listing the installed apps when "Ask each time" is on.
 */
private struct DirectionsPrompt: ViewModifier {
    @Binding var destination: DirectionsLauncher.Destination?
    @AppStorage(StorageKey.directionsApp) private var preferred = NavApp.apple.rawValue
    @AppStorage(StorageKey.directionsAsk) private var ask = false
    @Environment(\.openURL) private var openURL
    @State private var choices: [NavApp] = []
    @State private var asking = false

    func body(content: Content) -> some View {
        content
            .onChange(of: destination) {
                guard let destination else { return }
                switch DirectionsLauncher.device.decide(preferred: NavApp(rawValue: preferred), ask: ask) {
                case .open(let app): go(app, destination)
                case .ask(let apps): choices = apps; asking = true
                }
            }
            .confirmationDialog("Directions with", isPresented: $asking, titleVisibility: .visible, presenting: destination) { target in
                ForEach(choices) { app in
                    Button(app.name) { go(app, target) }
                }
            }
            .onChange(of: asking) { if !asking { destination = nil } }
            .sensoryFeedback(.impact(weight: .light), trigger: destination) { _, new in new != nil }
    }

    private func go(_ app: NavApp, _ target: DirectionsLauncher.Destination) {
        DirectionsLauncher.open(DirectionsLauncher.launch(app, to: target), openURL: openURL)
        destination = nil
    }
}

extension View {
    /** Opens directions to `destination` when it is set, in the app Settings › Directions chose. */
    func directionsPrompt(_ destination: Binding<DirectionsLauncher.Destination?>) -> some View {
        modifier(DirectionsPrompt(destination: destination))
    }
}
