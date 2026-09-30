import Foundation
import Testing
@testable import ServoMap

/** How Trends prints figures and dates, independent of the device's locale, and its chart scales. */
struct TrendFormatTests {
    @Test func figures() {
        #expect(TrendFormat.cents(240) == "240.0")
        #expect(TrendFormat.cents(1234.56) == "1234.6")
        #expect(TrendFormat.signed(42.8) == "+42.8")
        #expect(TrendFormat.signed(-0.6) == "−0.6")
        #expect(TrendFormat.signed(-0.04) == "0.0")
        #expect(TrendFormat.dollars(13.384) == "$13.38")
    }

    @Test func dates() {
        #expect(TrendFormat.dayMonth("2026-09-23") == "23 Sep")
        #expect(TrendFormat.dayLongMonth("2026-09-30") == "30 September")
        #expect(TrendFormat.month("2026-06-01") == "June")
        #expect(TrendFormat.since("2026-06-01") == "June")
        #expect(TrendFormat.since("2026-09-18") == "18 Sep")
        #expect(TrendFormat.adding(-7, to: "2026-03-03") == "2026-02-24")
        #expect(TrendFormat.adding(30, to: "2026-09-30") == "2026-10-30")
        #expect(TrendFormat.dayMonth("yesterday") == "yesterday")
    }

    @Test func todayUsesTheReadersCalendar() {
        var sydney = Calendar(identifier: .gregorian)
        sydney.timeZone = TimeZone(identifier: "Australia/Sydney")!
        // 30 Sep 2026 23:30 UTC is already 1 Oct in Sydney.
        let late = Date(timeIntervalSince1970: TrendMath.day("2026-09-30").timeIntervalSince1970 + 23.5 * 3600)
        #expect(TrendFormat.today(late, calendar: sydney) == "2026-10-01")
    }

    @Test func words() {
        #expect(TrendFormat.list(["NSW"]) == "NSW")
        #expect(TrendFormat.list(["NSW", "WA"]) == "NSW and WA")
        #expect(TrendFormat.list(["NSW", "WA", "TAS"]) == "NSW, WA and TAS")
        #expect(TrendFormat.word(4) == "four")
        #expect(TrendFormat.word(12) == "12")
        #expect(TrendFormat.days(1) == "1 day")
        #expect(TrendFormat.sentenceStart("the ACT") == "The ACT")
        #expect(StateName.short("act") == "the ACT")
        #expect(StateName.full("NSW") == "New South Wales")
        #expect(FuelType.u98.spoken == "Premium 98")
    }

    @Test func niceScalesUseRoundSteps() {
        #expect(ChartScale.step(for: 60, ticks: 3) == 20)
        #expect(ChartScale.step(for: 7, ticks: 3) == 2.5)
        let scale = ChartScale.nice([195, 246.8], ticks: 3, pad: 2)
        #expect(scale.domain == 180...260)
        #expect(scale.ticks == [180, 200, 220, 240, 260])
        #expect(ChartScale.nice([240]).domain.upperBound > 240)
        #expect(ChartScale.nice([]).domain == 0...1)
    }
}
