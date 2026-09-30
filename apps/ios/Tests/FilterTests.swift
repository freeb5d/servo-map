import Foundation
import Testing
@testable import ServoMap

@MainActor
struct FilterTests {
    private func store() -> Store {
        Store(stations: [
            Fixture.station("a", brand: "Metro Fuel", u91: 225.9, km: 2),
            Fixture.station("b", brand: "EG Ampol", u91: 238.6, diesel: 250.1, km: 6),
            Fixture.station("c", brand: "Costco", u91: 219.7, hoursOld: 3, km: 12),
            Fixture.station("d", brand: "BP", u91: 241.5, hoursOld: 8 * 24, km: 1),
            Fixture.station("e", brand: "Shell", u91: nil, diesel: 249.0),
        ])
    }

    @Test func ranksCheapestFirstAndDropsWeekOldPrices() {
        #expect(store().ranked.map(\.id) == ["c", "a", "b"])
    }

    @Test func weekOldPricesAreOutdatedNotHidden() {
        let s = store()
        #expect(s.outdated.map(\.id) == ["d"])
        // A station with no price for the fuel is neither ranked nor outdated.
        #expect(!s.outdated.contains { $0.id == "e" })
    }

    @Test func pricesUpToAWeekOldStillRank() {
        let s = Store(stations: [Fixture.station("x", u91: 230, hoursOld: 6 * 24), Fixture.station("y", u91: 231, hoursOld: 7 * 24 + 1)])
        #expect(s.ranked.map(\.id) == ["x"])
        #expect(s.outdated.map(\.id) == ["y"])
    }

    @Test func maxPrice() {
        var f = Filters(); f.maxPrice = 230
        #expect(store().matching(f).map(\.id) == ["c", "a"])
    }

    @Test func radius() {
        var f = Filters(); f.radiusKm = 5
        #expect(store().matching(f).map(\.id) == ["a"])
    }

    @Test func freshness() {
        var f = Filters(); f.freshHours = 1
        #expect(store().matching(f).map(\.id).contains("c") == false)
    }

    @Test func onlyAndHideBrands() {
        var only = Filters(); only.brands = ["ampol"]
        #expect(store().matching(only).map(\.id) == ["b"])
        var hide = only; hide.hideBrands = true
        #expect(store().matching(hide).map(\.id) == ["c", "a"])
    }

    @Test func membersOnlyAndAlsoSells() {
        var f = Filters(); f.hideMembersOnly = true
        #expect(store().matching(f).map(\.id) == ["a", "b"])
        var g = Filters(); g.alsoSells = [.diesel]
        #expect(store().matching(g).map(\.id) == ["b"])
    }

    @Test func activeCountCountsEachSetting() {
        var f = Filters()
        #expect(f.activeCount == 0)
        f.maxPrice = 230; f.brands = ["bp"]; f.alsoSells = [.e10]
        #expect(f.activeCount == 3)
        f.hiddenTiers = [.pricey]
        #expect(f.activeCount == 4)
        // The order sorts the list; it filters nothing.
        f.order = .nearest
        #expect(f.activeCount == 4)
    }

    @Test func hiddenTiersUseTheStoreTiers() {
        let prices: [Double] = [200, 210, 220, 230, 240, 250, 260, 270, 280]
        let s = Store(stations: prices.map { Fixture.station("p\(Int($0))", u91: $0) })
        s.filters.hiddenTiers = [.pricey]
        #expect(s.ranked.map { $0.price(.u91)?.price } == [200, 210, 220, 230, 240, 250])
        s.filters.hiddenTiers = [.cheap, .pricey]
        #expect(s.ranked.map { $0.price(.u91)?.price } == [230, 240, 250])
        // Tiers describe every station nearby, so hiding one does not move the cut points.
        #expect(s.range.cheapBelow == 220)
        #expect(s.range.midBelow == 250)
        s.filters.hiddenTiers = [.cheap, .fair, .pricey]
        #expect(s.ranked.isEmpty)
    }

    @Test func orderLeavesRankedCheapestFirst() {
        let s = store()
        s.filters.order = .nearest
        #expect(s.ranked.map(\.id) == ["c", "a", "b"])
    }

    @Test func cachedRankingFollowsFilterChanges() {
        let store = Store(stations: [Fixture.station("a", u91: 230), Fixture.station("b", brand: "Shell", u91: 220),
                                     Fixture.station("c", u91: 250)])
        #expect(store.ranked.map(\.id) == ["b", "a", "c"])
        #expect(store.localAverage == 700.0 / 3)
        store.filters.maxPrice = 235
        #expect(store.ranked.map(\.id) == ["b", "a"])
        // The average and tiers describe every station nearby, not just the ones that pass filters.
        #expect(store.localAverage == 700.0 / 3)
        store.filters = Filters()
        #expect(store.ranked.count == 3)
    }

    @Test func familyIsResolvedWhenAStationIsBuilt() throws {
        let json = #"{"id":"x","name":"Metro Croydon","brand":"Metro Fuel","address":"1 A St","suburb":"Croydon","state":"nsw","postcode":"2132","lat":-33.8,"lng":151.1,"prices":[],"distance":null}"#
        let station = try JSONDecoder().decode(Station.self, from: Data(json.utf8))
        #expect(station.family == BrandFamily.resolve("Metro Fuel"))
        #expect(Fixture.station("y", brand: "Shell").family == BrandFamily.resolve("Shell"))
    }

    @Test func inViewFollowsTheViewport() {
        let near = Fixture.station("n", u91: 230), far = Fixture.station("f", u91: 220)
        let farAway = Station(id: far.id, name: far.name, brand: far.brand, address: far.address, suburb: far.suburb,
                              state: far.state, postcode: far.postcode, lat: -34.5, lng: 150.5, prices: far.prices, distance: far.distance)
        let s = Store(stations: [near, farAway])
        #expect(s.inView.map(\.id) == ["f", "n"])
        s.viewport = Viewport(minLat: -34, maxLat: -33.5, minLng: 151, maxLng: 151.3)
        #expect(s.inView.map(\.id) == ["n"])
        s.viewport = Viewport(minLat: -33, maxLat: -32, minLng: 151, maxLng: 151.3)
        #expect(s.inView.isEmpty)
    }

    @Test func userLocationSurvivesMovingTheMap() async {
        let s = Store(stations: [])
        s.setUserLocation(-33.87, 151.2)
        #expect(s.located)
        s.viewport = Viewport(minLat: -34, maxLat: -33.5, minLng: 150, maxLng: 150.5)
        #expect(s.located)
    }
}
