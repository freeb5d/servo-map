import Foundation
import Testing
@testable import ServoMap

/** The Overview and States facts: every sentence states where a price is, from the data alone. */
struct StateFactsTests {
    private func snap(_ date: String, avg: Double, min: Double? = nil, max: Double? = nil, count: Int? = nil,
                      fuel: String = "U91") -> Snapshot {
        Snapshot(date: date, fuel: fuel, min: min ?? avg - 10, avg: avg, max: max ?? avg + 10, stationCount: count)
    }

    private var today: [StateLatest] {
        [StateLatest(state: "nsw", snapshot: snap("2026-09-30", avg: 240, min: 218.5, count: 1992)),
         StateLatest(state: "wa", snapshot: snap("2026-09-30", avg: 245.4, min: 195, count: 938)),
         StateLatest(state: "tas", snapshot: snap("2026-09-30", avg: 245.4, min: 226.9, count: 170)),
         StateLatest(state: "act", snapshot: snap("2026-09-30", avg: 246.8, min: 232.7, count: 53))]
    }

    // MARK: Overview

    @Test func latestKeepsStatesReportingTodayBiggestFirst() {
        let series = [
            "act": [snap("2026-09-30", avg: 246.8, count: 53)],
            "nsw": [snap("2026-09-29", avg: 240.2, count: 2050), snap("2026-09-30", avg: 240, count: 1992)],
            "wa": [snap("2026-09-30", avg: 245.4, count: 938)],
            "qld": [snap("2026-09-20", avg: 230, count: 900)],
        ]
        #expect(StateFacts.latest(series).map(\.state) == ["nsw", "wa", "act"])
    }

    @Test func factOfTheDayNamesTheLowestAndHighestState() {
        #expect(StateFacts.factOfTheDay(fuel: .u91, today)
            == "U91 averages 240.0¢ in NSW, the lowest of the four states reporting. The ACT is highest at 246.8¢.")
    }

    @Test func factOfTheDayForOneStateOrATie() {
        #expect(StateFacts.factOfTheDay(fuel: .diesel, [today[1]]) == "Diesel averages 245.4¢ in WA today.")
        #expect(StateFacts.factOfTheDay(fuel: .u91, [today[1], today[2]]) == "U91 averages 245.4¢ in all two states reporting.")
        #expect(StateFacts.factOfTheDay(fuel: .u91, []) == nil)
    }

    @Test func factsNeverAdvise() {
        let sentences = [StateFacts.factOfTheDay(fuel: .u91, today), StateFacts.widestGap(today)].compactMap { $0 }
        for text in sentences {
            for word in ["should", "fill up", "wait", "buy", "best time"] {
                #expect(!text.lowercased().contains(word), "\(text)")
            }
        }
    }

    @Test func widestGapIsTheCheapestStationFurthestUnderItsAverage() {
        #expect(StateFacts.widestGap(today) == "WA has the widest gap: its cheapest station is 50.4¢ under the state average.")
        #expect(StateFacts.widestGap([today[0]]) == nil)
    }

    // MARK: Gaps and small multiples

    @Test func missingRangesNameTheFirstAndLastDayWithoutData() {
        let series = [snap("2026-08-01", avg: 200), snap("2026-09-18", avg: 236), snap("2026-09-19", avg: 237),
                      snap("2026-09-21", avg: 238)]
        let gaps = StateFacts.missingRanges(series)
        #expect(gaps.map(\.first) == ["2026-08-02", "2026-09-20"])
        #expect(gaps.map(\.last) == ["2026-09-17", "2026-09-20"])
        #expect(StateFacts.gapLabel(first: "2026-08-02", last: "2026-09-17") == "No data 2 Aug – 17 Sep")
        #expect(StateFacts.gapLabel(first: "2026-09-20", last: "2026-09-20") == "No data 20 Sep")
        #expect(StateFacts.missingRanges([snap("2026-09-30", avg: 1)]).isEmpty)
    }

    @Test func smallMultiplesShareOneScaleRoundedToTwentyCents() {
        #expect(StateFacts.sharedScale([160.6, 181.8, 240.8, 246.8]) == 160...260)
        #expect(StateFacts.sharedScale([240, 240]) == 240...260)
        #expect(StateFacts.sharedScale([]) == 0...20)
    }

    @Test func aSeriesOfAFewDaysIsStillCollecting() {
        let days = (1...6).map { snap(String(format: "2026-09-%02d", $0), avg: 240) }
        #expect(StateFacts.isCollecting(days))
        #expect(!StateFacts.isCollecting(days + [snap("2026-09-07", avg: 240)]))
    }

    // MARK: States

    @Test func comparisonsNameTheirDayAndSkipDaysInsideAGap() {
        let series = [snap("2026-06-01", avg: 181.8), snap("2026-08-01", avg: 197.2), snap("2026-09-23", avg: 240.6),
                      snap("2026-09-30", avg: 240)]
        let changes = StateFacts.comparisons(series)
        #expect(changes.map(\.label) == ["vs 23 Sep", "vs 1 Aug", "vs 1 Jun"])
        #expect(abs(changes[0].change - -0.6) < 0.001)
        #expect(abs(changes[2].change - 58.2) < 0.001)

        // 7 days before 20 Sep is 13 Sep, inside the gap: left out, never swapped for 1 Aug.
        let afterGap = [snap("2026-08-01", avg: 197.2), snap("2026-09-18", avg: 236), snap("2026-09-20", avg: 238)]
        #expect(StateFacts.comparisons(afterGap).map(\.label) == ["vs 1 Aug"])
    }

    @Test func comparisonsAreNotRepeatedOrMadeAgainstToday() {
        let series = [snap("2026-09-01", avg: 230), snap("2026-09-08", avg: 235)]
        // 7 days back, the previous month's first day and the first day of data: 1 Sep appears once.
        #expect(StateFacts.comparisons(series).map(\.date) == ["2026-09-01"])
        #expect(StateFacts.comparisons([snap("2026-09-08", avg: 235)]).isEmpty)
    }

    @Test func previousMonthWrapsIntoLastYearInJanuary() {
        let series = [snap("2025-12-01", avg: 200), snap("2026-01-10", avg: 210)]
        #expect(StateFacts.comparisons(series).map(\.label) == ["vs 1 Dec"])
    }

    @Test func rangePositionPlacesTodayBetweenTheLowAndHigh() throws {
        let series = [snap("2026-06-29", avg: 160.6), snap("2026-09-24", avg: 240.8), snap("2026-09-30", avg: 240)]
        let position = try #require(StateFacts.rangePosition(series))
        #expect(position.low.date == "2026-06-29")
        #expect(position.high.date == "2026-09-24")
        #expect(abs(position.fraction - (240 - 160.6) / (240.8 - 160.6)) < 1e-9)
        #expect(StateFacts.rangeSentence(position, since: "2026-06-01") == "At the top of its range since June.")
        #expect(StateFacts.rangePosition([snap("2026-09-30", avg: 240)]) == nil)
    }

    @Test func rangeSentenceCoversEveryPartOfTheRange() {
        let s = snap("2026-09-30", avg: 1)
        let at = { (f: Double) in StateFacts.rangeSentence(RangePosition(low: s, high: s, today: s, fraction: f), since: "2026-09-18") }
        #expect(at(0) == "At the bottom of its range since 18 Sep.")
        #expect(at(0.2) == "Near the bottom of its range since 18 Sep.")
        #expect(at(0.5) == "In the middle of its range since 18 Sep.")
        #expect(at(0.8) == "Near the top of its range since 18 Sep.")
    }

    @Test func bandScaleCutsOutliersAndSaysSo() throws {
        let series = [snap("2026-06-01", avg: 181.8, min: 159.9, max: 293), snap("2026-06-29", avg: 160.6, min: 109.9, max: 293),
                      snap("2026-09-30", avg: 240, min: 218.5, max: 305)]
        let scale = try #require(StateFacts.bandScale(series))
        #expect(scale.domain == 120...270)
        #expect(scale.cutMax == 305)
        #expect(scale.cutMin == 109.9)
        #expect(scale.legend == "Cheapest to dearest station, cut outside 120–270¢")

        let tight = try #require(StateFacts.bandScale([snap("2026-09-01", avg: 200), snap("2026-09-02", avg: 240)]))
        #expect(tight.cutMax == nil && tight.cutMin == nil)
        #expect(tight.legend == "Cheapest to dearest station")
    }

    @Test func fuelRungsCompareTodaysFuelsWithU91() {
        let rungs = StateFacts.fuelRungs([
            .u91: snap("2026-09-30", avg: 240), .e10: snap("2026-09-30", avg: 236, fuel: "E10"),
            .u98: snap("2026-09-30", avg: 263.9, fuel: "U98"), .diesel: snap("2026-09-12", avg: 280, fuel: "Diesel"),
        ])
        #expect(rungs.map(\.fuel) == [.e10, .u91, .u98])
        #expect(abs((rungs[0].difference ?? 0) - -4) < 0.001)
        #expect(StateFacts.fuelFact(rungs, selected: .u91, tankLitres: 56) == "Premium 98 costs 23.9¢ more than U91: $13.38 on a 56\u{00A0}L tank.")
        #expect(StateFacts.fuelFact(rungs, selected: .u91, tankLitres: nil) == "Premium 98 costs 23.9¢ more than U91.")
        #expect(StateFacts.fuelFact(rungs, selected: .e10, tankLitres: 50) == "E10 costs 4.0¢ less than U91: $2.00 on a 50\u{00A0}L tank.")
        #expect(StateFacts.fuelFact(rungs, selected: .diesel, tankLitres: 50) == nil)
    }

    @Test func creditNamesEachSourceOnce() {
        #expect(StateFacts.credit(["nsw", "wa", "tas", "act"]) == "Via NSW FuelCheck, FuelWatch and FuelCheck TAS.")
        #expect(StateFacts.credit(["nsw"]) == "Via NSW FuelCheck.")
        #expect(StateFacts.credit([]) == nil)
    }
}
