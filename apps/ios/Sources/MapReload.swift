import Foundation

/**
 * Decides whether a map that has settled needs prices it has not fetched. A fetch covers a circle
 * around a centre; as long as the settled view still fits inside it, every station on screen is
 * already loaded and refetching would only replace the list with the same stations, redrawing
 * every annotation for nothing.
 */
enum MapReload {
    /** A circle of stations, fetched or wanted. */
    struct Area: Equatable, Sendable {
        var lat: Double
        var lng: Double
        var radiusKm: Int
    }

    /** Pans shorter than this never refetch on their own. */
    static let slackKm = 2.0

    /** Radius that reaches the edges of a map showing this span: half its longer side, rounded up. */
    static func reachKm(latitudeDelta: Double, longitudeDelta: Double) -> Int {
        Int((max(latitudeDelta, longitudeDelta) * kmPerDegree / 2).rounded(.up))
    }

    /**
     * How far to fetch for a view that reaches `reachKm`: twice as far, a view's width of margin
     * all round, so the next few pans stay inside what is loaded instead of each refetching.
     */
    static func fetchKm(reachKm: Int) -> Int { reachKm * 2 }

    /**
     * Whether `showing` (the settled view, as the radius that reaches its edges) needs stations
     * `loaded` did not fetch: the view reaches past the fetched circle, or the fetch was `capped`
     * and the view has zoomed well in. A capped fetch holds only the cheapest stations in its
     * circle, which still names the cheapest anywhere inside it but leaves a close-up view sparse.
     */
    static func needed(loaded: Area, capped: Bool, showing: Area) -> Bool {
        let outside = distanceKm(loaded, showing) + Double(showing.radiusKm) > Double(loaded.radiusKm) + slackKm
        let zoomedIn = capped && showing.radiusKm * 4 < loaded.radiusKm
        return outside || zoomedIn
    }

    private static let kmPerDegree = 111.32

    /** Equirectangular distance: at the tens of kilometres a fetch spans, metres off the great circle. */
    static func distanceKm(_ a: Area, _ b: Area) -> Double {
        let meanLat = (a.lat + b.lat) / 2 * .pi / 180
        let dLat = (b.lat - a.lat) * kmPerDegree
        let dLng = (b.lng - a.lng) * kmPerDegree * cos(meanLat)
        return (dLat * dLat + dLng * dLng).squareRoot()
    }
}
