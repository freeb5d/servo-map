import Foundation
import Testing
@testable import ServoMap

struct BrandChoiceTests {
    @Test func presentBrandsFollowTheBrandTableOrder() {
        let stations = [Fixture.station("a", brand: "Metro Fuel"), Fixture.station("b", brand: "BP"),
                        Fixture.station("c", brand: "Metro Fuel"), Fixture.station("d", brand: "EG Ampol")]
        #expect(BrandChoice.present(in: stations).map(\.id) == ["ampol", "bp", "metro"])
        #expect(BrandChoice.present(in: []).isEmpty)
    }

    @Test func everyBrandStartsOn() {
        #expect(BrandChoice.isOn("bp", in: Filters()))
    }

    @Test func toggleHidesThenRestoresTheDefault() {
        var f = Filters()
        BrandChoice.toggle("bp", in: &f, among: ["ampol", "bp", "metro"])
        #expect(f.brands == ["bp"])
        #expect(f.hideBrands)
        #expect(!BrandChoice.isOn("bp", in: f))
        #expect(BrandChoice.isOn("ampol", in: f))
        BrandChoice.toggle("bp", in: &f, among: ["ampol", "bp", "metro"])
        // Nothing hidden is the default, so Reset has nothing left to clear.
        #expect(f == Filters())
    }

    @Test func anOnlyTheseChoiceBecomesTheBrandsToHide() {
        var f = Filters()
        f.brands = ["ampol"]
        f.hideBrands = false
        BrandChoice.toggle("bp", in: &f, among: ["ampol", "bp", "metro"])
        #expect(f.hideBrands)
        #expect(f.brands == ["metro"])
        #expect(BrandChoice.isOn("ampol", in: f))
        #expect(BrandChoice.isOn("bp", in: f))
    }

    @Test func aHiddenBrandStaysHiddenWhenItIsNotLoaded() {
        var f = Filters()
        BrandChoice.toggle("costco", in: &f, among: ["costco", "bp"])
        BrandChoice.toggle("bp", in: &f, among: ["bp"])
        #expect(f.brands == ["costco", "bp"])
    }

    @Test func countLine() {
        #expect(BrandChoice.countLine(on: 8, of: 8) == "All brands")
        #expect(BrandChoice.countLine(on: 5, of: 8) == "5 of 8")
        #expect(BrandChoice.countLine(on: 0, of: 8) == "0 of 8")
        #expect(BrandChoice.countLine(on: 0, of: 0) == "All brands")
    }
}

struct FreshnessStepTests {
    @Test func stepsMapToHours() {
        #expect(FreshnessStep.allCases.map(\.hours) == [6, 24, 72, nil])
        #expect(FreshnessStep.allCases.map(\.short) == ["6 h", "24 h", "3 days", "A week"])
    }

    @Test func noLimitIsAWeek() {
        #expect(FreshnessStep(hours: nil) == .week)
    }

    @Test func exactAndInBetweenLimits() {
        #expect(FreshnessStep(hours: 6) == .sixHours)
        #expect(FreshnessStep(hours: 1) == .sixHours)
        #expect(FreshnessStep(hours: 24) == .day)
        #expect(FreshnessStep(hours: 48) == .threeDays)
        #expect(FreshnessStep(hours: 500) == .week)
    }

    @Test func roundTripsThroughHours() {
        for step in FreshnessStep.allCases {
            #expect(FreshnessStep(hours: step.hours) == step)
        }
    }
}

struct PriceHistogramTests {
    @Test func binsCoverEveryPriceAndTheHighestLandsLast() {
        let prices = [200.0, 201, 210, 219.9, 220]
        let h = PriceHistogram(prices, binCount: 4)
        #expect(h.bins.count == 4)
        #expect(h.bins.map(\.count) == [2, 0, 1, 2])
        #expect(h.bins.map(\.count).reduce(0, +) == prices.count)
        #expect(h.low == 200)
        #expect(h.high == 220)
        #expect(h.tallest == 2)
        #expect(h.bins[0].mid == 202.5)
    }

    @Test func emptyAndSinglePrice() {
        #expect(PriceHistogram([]).bins.isEmpty)
        #expect(PriceHistogram([]).low == nil)
        let one = PriceHistogram([225.9, 225.9])
        #expect(one.bins == [PriceHistogram.Bin(from: 225.9, to: 225.9, count: 2)])
    }

    @Test func pricesInViewSkipOldPricesAndStationsOffScreen() {
        let far = Fixture.station("f", u91: 210)
        let offScreen = Station(id: far.id, name: far.name, brand: far.brand, address: far.address, suburb: far.suburb,
                                state: far.state, postcode: far.postcode, lat: -34.5, lng: 150.5, prices: far.prices,
                                distance: far.distance)
        let stations = [Fixture.station("a", u91: 220), Fixture.station("old", u91: 200, hoursOld: 8 * 24),
                        Fixture.station("none", u91: nil, diesel: 250), offScreen]
        #expect(PriceHistogram.pricesInView(stations, fuel: .u91, viewport: nil).sorted() == [210, 220])
        let viewport = Viewport(minLat: -34, maxLat: -33.5, minLng: 151, maxLng: 151.3)
        #expect(PriceHistogram.pricesInView(stations, fuel: .u91, viewport: viewport) == [220])
    }

    @Test func cutLineUsesTheStoreTiers() {
        let range = PriceRange([200, 210, 220, 230, 240, 250, 260, 270, 280])
        #expect(PriceHistogram.cutLine(range) == "cheap to \(range.cheapBelow.formatted(.number.precision(.fractionLength(1)))), pricey over \(range.midBelow.formatted(.number.precision(.fractionLength(1))))")
        #expect(range.cheapBelow == 220)
        #expect(range.midBelow == 250)
    }
}

struct StationOrderTests {
    private let stations = [
        Fixture.station("cheap", u91: 210, hoursOld: 30, km: 8),
        Fixture.station("mid", u91: 220, hoursOld: 2, km: 1),
        Fixture.station("dear", u91: 230, hoursOld: 10, km: nil),
        Fixture.station("tie", u91: 240, hoursOld: 2, km: 1),
    ]

    @Test func cheapestKeepsTheRankedOrder() {
        #expect(StationOrder.cheapest.sorted(stations, fuel: .u91).map(\.id) == ["cheap", "mid", "dear", "tie"])
    }

    @Test func nearestPutsUnknownDistanceLastAndKeepsTiesCheapestFirst() {
        #expect(StationOrder.nearest.sorted(stations, fuel: .u91).map(\.id) == ["mid", "tie", "cheap", "dear"])
    }

    @Test func newestPriceFirst() {
        #expect(StationOrder.newest.sorted(stations, fuel: .u91).map(\.id) == ["mid", "tie", "dear", "cheap"])
    }

    @Test func captions() {
        #expect(StationOrder.allCases.map(\.caption) == ["cheapest first", "nearest first", "newest price first"])
    }
}

struct ShowStationsTests {
    @Test func title() {
        #expect(ShowStations.title(inView: 0, ranked: 0) == "No matches")
        #expect(ShowStations.title(inView: 0, ranked: 12) == "Show stations")
        #expect(ShowStations.title(inView: 1, ranked: 12) == "Show 1 station")
        #expect(ShowStations.title(inView: 42, ranked: 90) == "Show 42 stations")
    }
}
