import Testing
@testable import ServoMap

@MainActor
struct FilterTests {
    private func store() -> Store {
        Store(stations: [
            Fixture.station("a", brand: "Metro Fuel", u91: 225.9, km: 2),
            Fixture.station("b", brand: "EG Ampol", u91: 238.6, diesel: 250.1, km: 6),
            Fixture.station("c", brand: "Costco", u91: 219.7, hoursOld: 3, km: 12),
            Fixture.station("d", brand: "BP", u91: 241.5, hoursOld: 30, km: 1),
            Fixture.station("e", brand: "Shell", u91: nil, diesel: 249.0),
        ])
    }

    @Test func ranksCheapestFirstAndDropsDayOldPrices() {
        #expect(store().ranked.map(\.id) == ["c", "a", "b"])
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
    }
}
