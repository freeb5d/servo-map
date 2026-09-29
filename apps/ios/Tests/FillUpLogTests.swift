import Foundation
import Testing
@testable import ServoMap

@MainActor
struct FillUpLogTests {
    private func fill(_ day: String, litres: Double, price: Double, avg: Double?, at station: String = "Metro") -> FillUp {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .init(identifier: "UTC")
        return FillUp(date: f.date(from: day)!, stationID: "nsw-1", stationName: station, brand: "Metro Fuel",
                      fuel: .u91, litres: litres, centsPerLitre: price, areaAverage: avg)
    }

    @Test func costAndSaving() {
        let f = fill("2026-09-23", litres: 42.3, price: 225.9, avg: 240.3)
        #expect(abs(f.cost - 95.5557) < 0.001)
        #expect(abs(f.saved - 6.0912) < 0.001)
    }

    @Test func dearerThanAverageSavesNothing() {
        #expect(fill("2026-09-23", litres: 40, price: 250, avg: 240).saved == 0)
        #expect(fill("2026-09-23", litres: 40, price: 230, avg: nil).saved == 0)
    }

    @Test func monthSummaryOnlyCountsThatMonth() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .init(identifier: "UTC")!
        let log = [fill("2026-09-23", litres: 40, price: 225, avg: 240),
                   fill("2026-09-02", litres: 30, price: 230, avg: 230),
                   fill("2026-08-30", litres: 50, price: 200, avg: 210)]
        let s = MonthSummary.of(log, month: log[0].date, calendar: cal)
        #expect(s.count == 2)
        #expect(s.litres == 70)
        #expect(abs(s.spent - 159) < 0.001)
        #expect(abs(s.saved - 6) < 0.001)
    }

    @Test func persistsAndReloads() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "log-\(UUID()).json")
        let log = FillUpLog(url: url)
        let entry = fill("2026-09-23", litres: 40, price: 225, avg: 240)
        log.add(entry)
        #expect(FillUpLog(url: url).entries == [entry])
        log.remove([entry.id])
        #expect(FillUpLog(url: url).entries.isEmpty)
    }

    @Test func recentMonthsIncludeEmptyOnesOldestFirst() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .init(identifier: "UTC")!
        let log = [fill("2026-09-23", litres: 40, price: 225, avg: 240),
                   fill("2026-07-10", litres: 30, price: 200, avg: nil)]
        let months = MonthSummary.recent(log, months: 3, now: log[0].date, calendar: cal)
        #expect(months.map(\.summary.count) == [1, 0, 1])
        #expect(cal.component(.month, from: months[0].month) == 7)
        #expect(cal.component(.month, from: months[2].month) == 9)
    }

    @Test func habitsAcrossTheLog() throws {
        let log = [fill("2026-09-21", litres: 40, price: 220, avg: 240, at: "Ampol"),
                   fill("2026-09-11", litres: 20, price: 250, avg: 240, at: "Metro"),
                   fill("2026-09-01", litres: 40, price: 230, avg: nil, at: "Metro")]
        let h = try #require(LogHabits.of(log))
        #expect(abs(h.averageLitres - 100.0 / 3) < 0.001)
        #expect(abs(h.averagePrice - 230) < 0.001)       // (8800 + 5000 + 9200) / 100 litres
        #expect(h.averageUnder == 5)                    // (20 + -10) / 2, the unknown average is skipped
        #expect(h.daysBetween == 10)
        #expect(h.favourite?.name == "Metro")
        #expect(h.favourite?.count == 2)
    }

    @Test func habitsEdgeCases() throws {
        #expect(LogHabits.of([]) == nil)
        let one = try #require(LogHabits.of([fill("2026-09-21", litres: 40, price: 220, avg: nil)]))
        #expect(one.daysBetween == nil)
        #expect(one.averageUnder == nil)
        // A tie goes to the station filled at most recently.
        let tie = try #require(LogHabits.of([fill("2026-09-21", litres: 40, price: 220, avg: nil, at: "Ampol"),
                                             fill("2026-09-01", litres: 40, price: 220, avg: nil, at: "Metro")]))
        #expect(tie.favourite?.name == "Ampol")
    }
}
