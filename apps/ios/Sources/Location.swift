import CoreLocation
import Observation

/**
 * One-shot "use my location". The system prompt appears only when the user taps the button,
 * never at launch, and a denial leaves the app on its default place instead of blocking it.
 */
@MainActor @Observable
final class Location {
    enum State: Equatable { case idle, locating, denied, failed }

    private(set) var state: State = .idle
    private var session: CLServiceSession?

    func locate() async -> CLLocationCoordinate2D? {
        state = .locating
        session = CLServiceSession(authorization: .whenInUse)
        defer { session = nil }
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if update.authorizationDenied || update.authorizationDeniedGlobally {
                    state = .denied
                    return nil
                }
                if let location = update.location {
                    state = .idle
                    return location.coordinate
                }
            }
        } catch {
            state = .failed
        }
        if state == .locating { state = .failed }
        return nil
    }
}
