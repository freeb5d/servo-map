import Foundation
import SwiftUI
import Testing
@testable import ServoMap

struct AppearanceTests {
    @Test func mapsToAColourScheme() {
        #expect(Appearance.system.colorScheme == nil)
        #expect(Appearance.paper.colorScheme == .light)
        #expect(Appearance.ink.colorScheme == .dark)
    }

    @Test func storedValuesRoundTrip() {
        #expect(Appearance.allCases.map(\.rawValue) == ["system", "paper", "ink"])
        #expect(Appearance.allCases.allSatisfy { Appearance(rawValue: $0.rawValue) == $0 })
        #expect(Appearance(rawValue: "sepia") == nil)
    }
}

struct QuietHoursTests {
    @Test func overnightHoursWrapPastMidnight() {
        #expect(QuietHours.segments(start: 22, end: 7) == [0...(7.0 / 24), (22.0 / 24)...1])
    }

    @Test func daytimeHoursAreOneStretch() {
        #expect(QuietHours.segments(start: 9, end: 17) == [(9.0 / 24)...(17.0 / 24)])
    }

    @Test func noQuietHoursWhenStartIsEnd() {
        #expect(QuietHours.segments(start: 7, end: 7).isEmpty)
    }
}

@MainActor
struct MapPreferencesTests {
    private func defaults() -> UserDefaults {
        let name = "MapPreferencesTests-\(UUID())"
        return UserDefaults(suiteName: name)!
    }

    @Test func fuelFollowsTheCarUntilOneIsPicked() {
        let d = defaults()
        #expect(MapPreferences.launchFuel(d) == .u91)
        d.set("Diesel", forKey: StorageKey.defaultFuel)
        #expect(MapPreferences.launchFuel(d) == .diesel)
        d.set("E10", forKey: StorageKey.mapFuel)
        #expect(MapPreferences.launchFuel(d) == .e10)
    }

    @Test func compareRadiusIsOneOfTheChoices() {
        let d = defaults()
        #expect(MapPreferences.compareKm(d) == 20)
        d.set(5, forKey: StorageKey.compareKm)
        #expect(MapPreferences.compareKm(d) == 5)
        d.set(7, forKey: StorageKey.compareKm)
        #expect(MapPreferences.compareKm(d) == 20)
    }

    @Test func launchStoreCarriesTheSettings() {
        let d = defaults()
        d.set(10, forKey: StorageKey.compareKm)
        d.set(true, forKey: StorageKey.hideMembersOnly)
        let store = MapPreferences.launchStore(d)
        #expect(store.compareKm == 10)
        #expect(store.filters.hideMembersOnly)
    }
}

@MainActor
struct CompareRadiusTests {
    /** A station `km` east of Sydney CBD. */
    private func station(_ id: String, eastKm km: Double, price: Double) -> Station {
        let lng = Store.sydney.lng + km / (111.32 * cos(Store.sydney.lat * .pi / 180))
        return Station(id: id, name: id, brand: "Metro Fuel", address: "", suburb: "", state: "nsw", postcode: "2000",
                       lat: Store.sydney.lat, lng: lng,
                       prices: [FuelPrice(fuel: "U91", price: price, updatedAt: Fixture.now)], distance: km)
    }

    @Test func distanceMatchesTheGreatCircle() {
        // Sydney CBD to Parramatta is about 20 km.
        let km = Store.distanceKm((-33.8688, 151.2093), (-33.8150, 151.0011))
        #expect(abs(km - 20.0) < 1.5)
    }

    @Test func tiersCompareOnlyStationsInsideTheRadius() {
        let stations = [station("a", eastKm: 1, price: 200), station("b", eastKm: 2, price: 210),
                        station("c", eastKm: 3, price: 220), station("far", eastKm: 30, price: 150)]
        let near = Store.tierPrices(stations, fuel: .u91, around: Store.sydney, withinKm: 5)
        #expect(near.sorted() == [200, 210, 220])
        #expect(Store.tierPrices(stations, fuel: .u91, around: Store.sydney, withinKm: nil).count == 4)
    }

    @Test func tooFewInsideComparesEveryStation() {
        let stations = [station("a", eastKm: 1, price: 200), station("far", eastKm: 30, price: 150),
                        station("farther", eastKm: 40, price: 160)]
        #expect(Store.tierPrices(stations, fuel: .u91, around: Store.sydney, withinKm: 2).count == 3)
    }

    @Test func storeRangeFollowsTheRadius() {
        let stations = [station("a", eastKm: 1, price: 200), station("b", eastKm: 2, price: 210),
                        station("c", eastKm: 3, price: 220), station("far", eastKm: 30, price: 150),
                        station("far2", eastKm: 31, price: 155), station("far3", eastKm: 32, price: 160)]
        let store = Store(stations: stations)
        // Across all six, 200 is not in the cheapest third; within 5 km it is.
        #expect(store.range.tier(200) != .cheap)
        store.compareKm = 5
        #expect(store.range.tier(200) == .cheap)
        #expect(CompareRadius.inside(stations, fuel: .u91, around: Store.sydney, km: 5).map(\.id) == ["a", "b", "c"])
    }
}

struct CompareRingTests {
    @Test func fiftyKilometresFillsTheFrame() {
        let fill = CompareRing.fillRadius(in: CGSize(width: 342, height: 200))
        #expect(fill == 92)
        #expect(CompareRing.radius(km: 50, fill: fill) == fill)
    }

    @Test func ringsGrowWithEveryChoiceAndTwoKilometresIsSmall() {
        let radii = MapPreferences.compareChoices.map { CompareRing.radius(km: $0, fill: 100) }
        #expect(radii == radii.sorted())
        #expect(Set(radii).count == radii.count)
        // Small, but clear of the 14 pt home dot.
        #expect(radii[0] > 7 && radii[0] < 25)
    }

    @Test func radiusIsClampedToTheScale() {
        #expect(CompareRing.radius(km: 80, fill: 100) == 100)
        #expect(CompareRing.radius(km: -1, fill: 100) == 0)
    }

    @Test func eachChoiceTakesInMoreDots() {
        let counts = MapPreferences.compareChoices.map { km in
            CompareRing.dots.filter { CompareRing.isInside($0, ringRadius: CompareRing.radius(km: km, fill: 100), fill: 100) }.count
        }
        #expect(counts == counts.sorted())
        #expect(Set(counts).count == counts.count)
        #expect(counts.last! < CompareRing.dots.count)   // some always sit outside, faint
    }
}

struct LaunchRouteTests {
    @Test func opensOnNearbyByDefault() {
        let route = LaunchRoute(arguments: ["ServoMap"])
        #expect(route.tab == .nearby)
        #expect(!route.openYou)
        #expect(route.settingsPage == nil)
    }

    @Test func tabNames() {
        #expect(LaunchRoute(arguments: ["-tab", "map"]).tab == .nearby)
        #expect(LaunchRoute(arguments: ["-tab", "trends"]).tab == .trends)
        #expect(LaunchRoute(arguments: ["-tab", "search"]).tab == .search)
        #expect(LaunchRoute(arguments: ["-tab", "settings"]).tab == .settings)
        #expect(LaunchRoute(arguments: ["-tab", "nonsense"]).tab == .nearby)
    }

    @Test func youPagesOpenTheYouSheetOverTheMap() {
        let you = LaunchRoute(arguments: ["-tab", "you"])
        #expect(you.openYou && you.youPage == nil && you.tab == .nearby)
        let log = LaunchRoute(arguments: ["-tab", "log"])
        #expect(log.openYou && log.youPage == .log && log.tab == .nearby)
    }

    @Test func settingsPagesOpenTheSettingsTab() {
        let route = LaunchRoute(arguments: ["-settings", "directions"])
        #expect(route.tab == .settings)
        #expect(route.settingsPage == .directions)
        #expect(LaunchRoute(arguments: ["-settings", "nope"]).settingsPage == nil)
    }

    @Test func flags() {
        let route = LaunchRoute(arguments: ["-filters", "-detail", "-widgets"])
        #expect(route.openFilters && route.openDetail && route.widgets)
    }
}
