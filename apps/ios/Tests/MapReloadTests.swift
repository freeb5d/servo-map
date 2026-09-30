import Testing
@testable import ServoMap

struct MapReloadTests {
    private typealias Area = MapReload.Area
    private let loaded = Area(lat: -33.87, lng: 151.21, radiusKm: 20)
    /** About 0.009 degrees of latitude per km. */
    private func north(_ km: Double, radiusKm: Int) -> Area {
        Area(lat: loaded.lat + km / 111.32, lng: loaded.lng, radiusKm: radiusKm)
    }

    @Test func panInsideTheLoadedCircleKeepsTheStations() {
        // 5 km north with a 10 km view: 15 km from the centre, inside the 20 km fetch.
        #expect(!MapReload.needed(loaded: loaded, capped: false, showing: north(5, radiusKm: 10)))
    }

    @Test func panPastTheLoadedCircleRefetches() {
        #expect(MapReload.needed(loaded: loaded, capped: false, showing: north(15, radiusKm: 10)))
    }

    @Test func zoomingOutPastTheCircleRefetches() {
        #expect(MapReload.needed(loaded: loaded, capped: false, showing: north(0, radiusKm: 30)))
    }

    @Test func zoomingInNeverRefetches() {
        #expect(!MapReload.needed(loaded: loaded, capped: false, showing: north(1, radiusKm: 5)))
    }

    @Test func smallOvershootIsWithinTheSlack() {
        // The view reaches 1.5 km past the fetch: under the 2 km slack.
        #expect(!MapReload.needed(loaded: loaded, capped: false, showing: north(11.5, radiusKm: 10)))
    }

    @Test func cappedFetchCoversPansInsideItsCircle() {
        // It holds the cheapest stations in the circle, so the cheapest in any view inside it is loaded.
        #expect(!MapReload.needed(loaded: loaded, capped: true, showing: north(5, radiusKm: 10)))
        #expect(MapReload.needed(loaded: loaded, capped: true, showing: north(15, radiusKm: 10)))
    }

    @Test func cappedFetchRefetchesWhenZoomedWellIn() {
        // Up close it is sparse: past a quarter of its radius, fetch the smaller area in full.
        #expect(!MapReload.needed(loaded: loaded, capped: true, showing: north(1, radiusKm: 5)))
        #expect(MapReload.needed(loaded: loaded, capped: true, showing: north(1, radiusKm: 4)))
        #expect(!MapReload.needed(loaded: loaded, capped: false, showing: north(1, radiusKm: 4)))
    }

    @Test func fullyZoomedOutDoesNotRefetchInPlace() {
        // The fetch radius is capped at 50 km, so a wider view that has not moved needs nothing new.
        let wide = Area(lat: -33.87, lng: 151.21, radiusKm: 50)
        let showing = Area(lat: -33.87, lng: 151.21, radiusKm: Store.fetchRadius(120))
        #expect(!MapReload.needed(loaded: wide, capped: false, showing: showing))
        #expect(!MapReload.needed(loaded: wide, capped: true, showing: showing))
    }

    @Test func reachIsHalfTheLongerSide() {
        #expect(MapReload.reachKm(latitudeDelta: 0.2, longitudeDelta: 0.1) == 12)
        #expect(MapReload.reachKm(latitudeDelta: 0.01, longitudeDelta: 0.02) == 2)
    }

    @Test func aRefetchLeavesRoomForTheNextPans() {
        // A view reaching 5 km fetches 10 km, so panning its own half-width stays inside the fetch.
        let fetched = Area(lat: loaded.lat, lng: loaded.lng, radiusKm: MapReload.fetchKm(reachKm: 5))
        #expect(fetched.radiusKm == 10)
        let panned = Area(lat: loaded.lat + 5 / 111.32, lng: loaded.lng, radiusKm: 5)
        #expect(!MapReload.needed(loaded: fetched, capped: false, showing: panned))
    }

    @Test func distanceMatchesADegree() {
        let a = Area(lat: -34, lng: 151, radiusKm: 1), b = Area(lat: -33, lng: 151, radiusKm: 1)
        #expect(abs(MapReload.distanceKm(a, b) - 111.32) < 0.01)
        // A degree of longitude shrinks with latitude: about 92 km at Sydney.
        let c = Area(lat: -33.87, lng: 151, radiusKm: 1), d = Area(lat: -33.87, lng: 152, radiusKm: 1)
        #expect(abs(MapReload.distanceKm(c, d) - 92.4) < 0.5)
    }

    @Test func fetchRadiusIsClamped() {
        #expect(Store.fetchRadius(1) == 5)
        #expect(Store.fetchRadius(12) == 12)
        #expect(Store.fetchRadius(400) == 50)
    }
}
