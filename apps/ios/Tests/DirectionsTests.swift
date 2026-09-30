import Foundation
import Testing
@testable import ServoMap

struct DirectionsTests {
    private let named = DirectionsLauncher.Destination(lat: -33.8688, lng: 151.2093, name: "Metro Fuel Glebe")
    private let unnamed = DirectionsLauncher.Destination(lat: -33.8688, lng: 151.2093, name: nil)

    /** A launcher on an iPhone with these apps' schemes answering. */
    private func launcher(installed: Set<String>) -> DirectionsLauncher {
        DirectionsLauncher { url in url.scheme.map(installed.contains) ?? false }
    }

    @Test func appleMapsTakesTheNamedDestination() {
        #expect(DirectionsLauncher.launch(.apple, to: named) == .appleMaps(named))
        #expect(DirectionsLauncher.launch(.apple, to: unnamed) == .appleMaps(unnamed))
    }

    @Test func googleMapsDrivesToTheCoordinates() {
        let url = URL(string: "comgooglemaps://?daddr=-33.868800,151.209300&directionsmode=driving")!
        #expect(DirectionsLauncher.launch(.google, to: unnamed) == .url(url))
        // Its scheme has no label for coordinates, and the name as the destination would be searched for.
        #expect(DirectionsLauncher.launch(.google, to: named) == .url(url))
    }

    @Test func wazeNavigatesToTheCoordinates() {
        let url = URL(string: "waze://?ll=-33.868800,151.209300&navigate=yes")!
        #expect(DirectionsLauncher.launch(.waze, to: unnamed) == .url(url))
        #expect(DirectionsLauncher.launch(.waze, to: named) == .url(url))
    }

    @Test func coordinatesKeepAFullStopInEveryLocale() throws {
        let far = DirectionsLauncher.Destination(lat: -31.95, lng: 115.86, name: nil)
        guard case .url(let url) = DirectionsLauncher.launch(.waze, to: far) else {
            Issue.record("Waze opens by URL")
            return
        }
        #expect(url.absoluteString == "waze://?ll=-31.950000,115.860000&navigate=yes")
    }

    @Test func appleMapsIsAlwaysOffered() {
        #expect(launcher(installed: []).offered == [.apple])
    }

    @Test func otherAppsOnlyWhenInstalled() {
        #expect(launcher(installed: ["comgooglemaps"]).offered == [.apple, .google])
        #expect(launcher(installed: ["waze"]).offered == [.apple, .waze])
        #expect(launcher(installed: ["comgooglemaps", "waze"]).offered == [.apple, .google, .waze])
    }

    @Test func opensTheChosenAppWhileInstalled() {
        let both = launcher(installed: ["comgooglemaps", "waze"])
        #expect(both.decide(preferred: .waze, ask: false) == .open(.waze))
        #expect(both.decide(preferred: nil, ask: false) == .open(.apple))
        // Google Maps was removed since it was chosen: back to Apple Maps.
        #expect(launcher(installed: ["waze"]).decide(preferred: .google, ask: false) == .open(.apple))
    }

    @Test func asksOnlyWithMoreThanOneApp() {
        #expect(launcher(installed: ["waze"]).decide(preferred: .waze, ask: true) == .ask([.apple, .waze]))
        #expect(launcher(installed: []).decide(preferred: .google, ask: true) == .open(.apple))
    }
}
