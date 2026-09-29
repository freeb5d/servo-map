import Testing
@testable import ServoMap

struct TrendMathTests {
    private let series = [
        Fixture.snapshot("2026-07-01", 170), Fixture.snapshot("2026-07-02", 172), Fixture.snapshot("2026-07-03", 175),
        Fixture.snapshot("2026-09-20", 236), Fixture.snapshot("2026-09-21", 238), Fixture.snapshot("2026-09-28", 240),
    ]

    @Test func missingDaysStartNewRuns() {
        let runs = TrendMath.runs(series)
        #expect(runs.map(\.count) == [3, 2, 1])
        #expect(TrendMath.gaps(series).count == 2)
    }

    @Test func verdictUsesWindowLength() {
        #expect(TrendMath.verdict(series) == "At the 90-day high.")
        let falling = [Fixture.snapshot("2026-09-01", 240), Fixture.snapshot("2026-09-02", 200), Fixture.snapshot("2026-09-03", 201)]
        #expect(TrendMath.verdict(falling) == "Near the 3-day low.")
        #expect(TrendMath.verdict([Fixture.snapshot("2026-09-01", 200)]) == nil)
    }

    @Test func weekChangeNeedsAReportNearTheTarget() {
        // 28 Sep (240) against 21 Sep (238).
        #expect(TrendMath.change(series, days: 7) == 2)
        #expect(TrendMath.change(series, days: 30) == nil)
    }

    @Test func windowKeepsTheTrailingDays() {
        #expect(TrendMath.window(series, days: 10).map(\.avg) == [236, 238, 240])
        #expect(TrendMath.window(series, days: nil).count == series.count)
    }

    @Test func weekdaysStartOnMonday() {
        let days = TrendMath.weekdays(series)
        #expect(days.map(\.0) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        // 21 and 28 Sep 2026 are both Mondays: (238 + 240) / 2.
        #expect(days[0].1 == 239)
    }
}
