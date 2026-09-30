import CoreGraphics
import Foundation
import Observation
import Testing
@testable import ServoMap

/**
 * What a settle costs the map, on a 2,000-station field. Each map update re-lays out every
 * annotation, so these count the two things that multiply: how many updates a pan causes and how
 * many annotations each one carries. Numbers are printed as `PERF` lines for the pull request.
 */
@MainActor
struct MapPerfTests {
    /** A 402 x 874 pt screen (iPhone 17 Pro) showing `span` degrees around a centre, north up. */
    private struct Screen {
        let lat: Double, lng: Double, span: Double
        let size = CGSize(width: 402, height: 874)
        var viewport: Viewport {
            Viewport(minLat: lat - span * size.height / size.width / 2, maxLat: lat + span * size.height / size.width / 2,
                     minLng: lng - span / 2, maxLng: lng + span / 2)
        }
        func point(_ s: Station) -> CGPoint? {
            CGPoint(x: (s.lng - lng) / span * size.width + size.width / 2,
                    y: (lat - s.lat) / span * size.width + size.height / 2)
        }
    }

    private final class Counter: @unchecked Sendable { var count = 0 }

    /** Settles the map 30 times, 0.01 degrees east each, counting changes seen by readers of `read`. */
    private func pan<T>(_ store: Store, read: @escaping () -> T) -> Int {
        let seen = Counter()
        for step in 0..<30 {
            withObservationTracking { _ = read() } onChange: { seen.count += 1 }
            store.viewport = Screen(lat: -33.85, lng: 150.9 + Double(step) * 0.01, span: 0.2).viewport
        }
        return seen.count
    }

    @Test func aSettleThatKeepsTheCheapestDoesNotRedrawTheMap() {
        let store = Store(stations: Fixture.field(2_000))
        let listUpdates = pan(store) { store.inView }
        store.viewport = nil
        let mapUpdates = pan(store) { store.cheapestInView }
        print("PERF settles=30 inViewChanges=\(listUpdates) cheapestInViewChanges=\(mapUpdates)")
        // Before: the map read `inView`, so every settle that changed the list redrew every annotation.
        #expect(listUpdates == 30)
        #expect(mapUpdates < listUpdates / 2)
    }

    @Test func cheapestInViewFollowsTheViewport() {
        let store = Store(stations: Fixture.field(2_000))
        #expect(store.cheapestInView == store.ranked.first)
        store.viewport = Screen(lat: -33.85, lng: 151.0, span: 0.1).viewport
        #expect(store.cheapestInView == store.inView.first)
        #expect(store.cheapestInView != nil)
        store.viewport = Viewport(minLat: 10, maxLat: 11, minLng: 10, maxLng: 11)
        #expect(store.cheapestInView == nil)
    }

    /** Annotations on screen, which MapKit gives a hosted view each, zoomed in to out. */
    @Test(arguments: [0.05, 0.2, 0.9])
    func annotationViewsOnScreen(span: Double) {
        let store = Store(stations: Fixture.field(2_000))
        let screen = Screen(lat: -33.85, lng: 151.0, span: span)
        let bounds = CGRect(origin: .zero, size: screen.size)
        store.viewport = screen.viewport
        let clock = ContinuousClock()
        var placement = TagPlacement.Result()
        var dots = Set<String>()
        let pass = clock.measure {
            placement = TagPlacement.choose(store.ranked, id: \.id, point: screen.point, visible: bounds)
            dots = MapDots.choose(store.ranked + store.outdated, id: \.id, lat: \.lat, lng: \.lng,
                                  degreesPerPoint: span / screen.size.width)
        }
        let onScreen = { (s: Station) in screen.point(s).map(bounds.contains) ?? false }
        let tagged = placement.tagged.union([store.cheapestInView?.id].compactMap { $0 })
        let dotted = store.ranked.filter { !tagged.contains($0.id) && !placement.hiddenDots.contains($0.id) } + store.outdated
        // Before: every ranked station not under a tag was a dot.
        let before = tagged.count + dotted.filter(onScreen).count
        let after = tagged.count + dotted.filter { onScreen($0) && dots.contains($0.id) }.count
        print("PERF span=\(span) annotationViewsBefore=\(before) annotationViewsAfter=\(after) placementPass=\(pass)")
        #expect(after <= before)
    }

    @Test func panningKeepsTheSameDots() {
        let stations = Fixture.field(2_000)
        let scale = 0.2 / 402
        let first = MapDots.choose(stations, id: \.id, lat: \.lat, lng: \.lng, degreesPerPoint: scale)
        // A settle at the same zoom must not add or drop dots, or it would cost a map update of its own.
        #expect(MapDots.choose(stations, id: \.id, lat: \.lat, lng: \.lng, degreesPerPoint: scale * 1.05) == first)
    }

    @Test func rankingTwoThousandStations() {
        let clock = ContinuousClock()
        var store: Store!
        let build = clock.measure { store = Store(stations: Fixture.field(2_000)) }
        let refilter = clock.measure { store.filters.maxPrice = 250 }
        let settle = clock.measure { store.viewport = Screen(lat: -33.85, lng: 151.0, span: 0.2).viewport }
        print("PERF stations=2000 derive=\(build) refilter=\(refilter) settle=\(settle)")
        #expect(store.ranked.count > 0)
    }
}
