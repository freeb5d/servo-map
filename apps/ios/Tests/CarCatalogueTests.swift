import Foundation
import Testing
@testable import ServoMap

struct CarCatalogueTests {
    private func car(_ make: String, _ model: String, _ from: Int, _ to: Int? = nil, body: String = "suv", tank: Int = 56, fuel: String = "U91") -> Vehicle {
        Vehicle(id: "\(make)-\(model)-\(from)".lowercased(), make: make, model: model, fromYear: from, toYear: to,
                body: body, fuel: fuel, tankLitres: tank, source: "https://www.carsguide.com.au/x")
    }

    private var mazda: [Vehicle] {
        [car("Mazda", "CX-5", 2015, 2016), car("Mazda", "CX-9", 2018, tank: 72), car("Mazda", "CX-5", 2017),
         car("Mazda", "CX-9", 2016, 2017, tank: 74), car("Mazda", "Mazda2", 2015, 2023, body: "hatch", tank: 44),
         car("Mazda", "BT-50", 2021, body: "ute", tank: 76, fuel: "Diesel")]
    }

    // MARK: Grouping generations into models

    @Test func groupsGenerationsIntoModelsNewestFirst() throws {
        let models = CarModel.group(mazda)
        #expect(models.map(\.model) == ["BT-50", "CX-5", "CX-9", "Mazda2"])
        let cx5 = try #require(models.first { $0.model == "CX-5" })
        #expect(cx5.generations.map(\.fromYear) == [2017, 2015])
        #expect(cx5.newest.id == "mazda-cx-5-2017")
        #expect(cx5.id == "Mazda|CX-5")
    }

    @Test func keepsSameNamedModelsOfDifferentMakesApart() {
        let models = CarModel.group([car("Toyota", "Corolla", 2019), car("Holden", "Corolla", 2000)])
        #expect(models.count == 2)
        #expect(models.map(\.make) == ["Holden", "Toyota"])
    }

    @Test func groupsModelsIntoMakesWithBodyCounts() throws {
        let makes = CarMake.group(mazda + [car("Audi", "Q5", 2018)])
        #expect(makes.map(\.name) == ["Audi", "Mazda"])
        let bodies = try #require(makes.last).bodies
        #expect(bodies.map(\.body) == [.suv, .hatch, .ute])
        #expect(bodies.map(\.count) == [2, 1, 1])
    }

    @Test func mostCommonMakesHaveTheMostModels() {
        let makes = CarMake.group(mazda + [car("Audi", "Q5", 2018), car("Kia", "Rio", 2017), car("Kia", "Sportage", 2016)])
        #expect(CarMake.mostCommon(makes, count: 2).map(\.name) == ["Mazda", "Kia"])
        // Ties keep alphabetical order.
        #expect(CarMake.mostCommon(CarMake.group([car("Kia", "Rio", 2017), car("Audi", "Q5", 2018)]), count: 2).map(\.name) == ["Audi", "Kia"])
    }

    // MARK: Labels

    @Test func tankIsARangeOnlyWhenGenerationsDiffer() {
        let models = CarModel.group(mazda)
        #expect(models.first { $0.model == "CX-5" }?.tankLabel == "56")
        #expect(models.first { $0.model == "CX-9" }?.tankLabel == "72–74")
    }

    @Test func yearsSpanEveryGeneration() {
        let models = CarModel.group(mazda)
        #expect(models.first { $0.model == "CX-5" }?.years == "2015 on")
        #expect(models.first { $0.model == "Mazda2" }?.years == "2015–2023")
        #expect(CarModel.group([car("Holden", "Commodore", 2013, 2017), car("Holden", "Commodore", 2018, 2020)]).first?.years == "2013–2020")
        #expect(car("Mazda", "CX-5", 2015, 2016).yearRange == "2015 – 2016")
        #expect(car("Mazda", "CX-5", 2017).yearRange == "2017 – now")
    }

    // MARK: Skipping the Years step

    @Test func asksForYearsOnlyWhenThereIsAChoice() {
        let models = CarModel.group(mazda)
        #expect(models.first { $0.model == "CX-5" }?.asksForYears == true)
        #expect(models.first { $0.model == "Mazda2" }?.asksForYears == false)
        #expect(models.first { $0.model == "BT-50" }?.asksForYears == false)
    }

    // MARK: Marks and pictures

    @Test func makeSlugsMatchTheLogoFiles() {
        #expect(CarMake.slug("Mazda") == "mazda")
        #expect(CarMake.slug("Land Rover") == "land-rover")
        #expect(CarMake.slug("Mercedes-Benz") == "mercedes-benz")
        #expect(CarMake.monogram("Holden") == "HOL")
        #expect(CarMake.monogram("GWM") == "GWM")
        #expect(CarMake.monogram("Land Rover") == "LR")
    }

    @Test func picturePathPrefersTheAPIThenTheSharedRule() {
        // A generation with its own render (design/car-renders) and one the catalogue does not have.
        #expect(car("Mazda", "CX-5", 2017).imagePath == "/cars/mazda-cx-5-2017.jpg")
        var unlisted = car("Tesla", "Model Y", 2020)
        #expect(unlisted.imagePath == "/cars/generic-suv.jpg")
        unlisted.image = "/cars/from-the-api.jpg"
        #expect(unlisted.imagePath == "/cars/from-the-api.jpg")
        #expect(VehicleImage.path(id: nil, body: nil) == "/cars/generic-hatch.jpg")
        #expect(VehicleImage.path(id: nil, body: "ute") == "/cars/generic-ute.jpg")
    }

    @MainActor @Test func catalogueFindsAGenerationById() {
        let catalogue = VehicleCatalogue(vehicles: mazda)
        #expect(catalogue.phase == .loaded)
        #expect(catalogue.vehicle(id: "mazda-cx-5-2015")?.toYear == 2016)
        #expect(catalogue.vehicle(id: "tesla-model-3-2019") == nil)
        #expect(catalogue.model(of: car("Mazda", "CX-5", 2017))?.generations.count == 2)
    }
}

struct FullTankTests {
    private let now = Fixture.now

    private func station(_ id: String, _ price: Double?, km: Double?, hoursOld: Double = 1) -> Station {
        Fixture.station(id, u91: price, hoursOld: hoursOld, km: km)
    }

    @Test func pricesATankAtTheCheapestAverageAndDearestWithinFiveKilometres() throws {
        let stations = [station("a", 220.0, km: 1), station("b", 230.0, km: 2), station("c", 240.0, km: 4.9),
                        station("far", 180.0, km: 12)]
        let tank = try #require(FullTank.near(stations, fuel: .u91, litres: 50, loadedKm: 20, now: now))
        #expect(tank.withinKm == 5)
        #expect(tank.cheapestPrice == 220)
        #expect(abs(tank.cheapest - 110) < 0.001)
        #expect(abs(tank.average - 115) < 0.001)
        #expect(abs(tank.dearest - 120) < 0.001)
        #expect(abs(tank.averagePosition - 0.5) < 0.001)
        #expect(abs(tank.spread - 10) < 0.001)
    }

    @Test func leavesOutPricesMoreThanAWeekOld() throws {
        let stations = [station("old", 150.0, km: 1, hoursOld: 24 * 8), station("a", 220.0, km: 1)]
        let tank = try #require(FullTank.near(stations, fuel: .u91, litres: 40, loadedKm: 20, now: now))
        #expect(tank.cheapestPrice == 220)
    }

    @Test func widensToEveryLoadedStationWhenNoneIsClose() throws {
        let stations = [station("a", 210.0, km: 8), station("b", 230.0, km: 15)]
        let tank = try #require(FullTank.near(stations, fuel: .u91, litres: 50, loadedKm: 20, now: now))
        #expect(tank.withinKm == 20)
        #expect(abs(tank.cheapest - 105) < 0.001)
    }

    @Test func isNilWithoutAPriceOrATank() {
        #expect(FullTank.near([station("a", nil, km: 1)], fuel: .u91, litres: 50, loadedKm: 20, now: now) == nil)
        #expect(FullTank.near([station("a", 220.0, km: 1)], fuel: .u91, litres: 0, loadedKm: 20, now: now) == nil)
        #expect(FullTank.near([station("a", 220.0, km: 1)], fuel: .diesel, litres: 50, loadedKm: 20, now: now) == nil)
    }

    @Test func oneStationPutsTheAverageMidway() throws {
        let tank = try #require(FullTank.near([station("a", 220.0, km: 1)], fuel: .u91, litres: 50, loadedKm: 20, now: now))
        #expect(tank.averagePosition == 0.5)
        #expect(tank.spread == 0)
    }

    @Test func carHistoryCountsFillUpsSinceTheCarWasChosen() throws {
        let day: TimeInterval = 86_400
        let fills = [
            FillUp(date: now.addingTimeInterval(-10 * day), stationID: "a", stationName: "A", brand: "BP", fuel: .u91, litres: 40, centsPerLitre: 200, areaAverage: nil),
            FillUp(date: now.addingTimeInterval(-2 * day), stationID: "a", stationName: "A", brand: "BP", fuel: .u91, litres: 30, centsPerLitre: 240, areaAverage: nil),
            FillUp(date: now.addingTimeInterval(-1 * day), stationID: "a", stationName: "A", brand: "BP", fuel: .u91, litres: 10, centsPerLitre: 220, areaAverage: nil),
        ]
        let since = now.addingTimeInterval(-5 * day)
        let history = try #require(CarHistory.of(fills, since: since))
        #expect(history.count == 2)
        #expect(history.litres == 40)
        #expect(abs(history.averagePaid - 235) < 0.001)
        #expect(history.since == since)
        #expect(CarHistory.of(fills, since: nil)?.count == 3)
        #expect(CarHistory.of(fills, since: now) == nil)
    }
}
