import Foundation

/** One state's latest day for a fuel. */
struct StateLatest: Equatable, Sendable {
    let state: String
    let snapshot: Snapshot
}

/** A change against an earlier day, labelled with the day it compares to ("vs 23 Sep"). */
struct Comparison: Equatable, Sendable {
    let date: String
    let change: Double
    var label: String { "vs \(TrendFormat.dayMonth(date))" }
}

/** Where the latest average sits between the series' lowest and highest average. */
struct RangePosition: Equatable, Sendable {
    let low: Snapshot
    let high: Snapshot
    let today: Snapshot
    /** 0 at the low, 1 at the high. */
    let fraction: Double
}

/** A band chart's y axis, and whether it cuts off prices far from the average at either end. */
struct BandScale: Equatable, Sendable {
    let domain: ClosedRange<Double>
    /** The dearest price in the series when it is above the top of `domain`; nil when nothing is cut. */
    let cutMax: Double?
    /** The cheapest price in the series when it is below the bottom of `domain`; nil when nothing is cut. */
    var cutMin: Double? = nil

    /** The band's legend, saying where it is cut so it never looks narrower than it is. */
    var legend: String {
        let lo = Int(domain.lowerBound), hi = Int(domain.upperBound)
        switch (cutMin != nil, cutMax != nil) {
        case (true, true): return "Cheapest to dearest station, cut outside \(lo)–\(hi)¢"
        case (true, false): return "Cheapest to dearest station, cut below \(lo)¢"
        case (false, true): return "Cheapest to dearest station, cut at \(hi)¢"
        case (false, false): return "Cheapest to dearest station"
        }
    }
}

/** One fuel on the "Every fuel, today" scale. */
struct FuelRung: Equatable, Sendable {
    let fuel: FuelType
    let average: Double
    /** Against U91; nil when U91 has no price that day. */
    let difference: Double?
}

/**
 * Facts read off the daily state series for the Overview and States pages. Each states where a price
 * is, never what to do about it (docs/design/system.md, "Facts, not advice").
 */
enum StateFacts {
    /** A series shorter than this many days is drawn as "Collecting since …" rather than a line. */
    static let collectingBelowDays = 7

    /** Each state's latest snapshot, keeping only states reporting on the newest day (or the day before). */
    static func latest(_ series: [String: [Snapshot]]) -> [StateLatest] {
        let rows = series.compactMap { state, s in s.last.map { StateLatest(state: state, snapshot: $0) } }
        guard let newest = rows.map({ TrendMath.day($0.snapshot.date) }).max() else { return [] }
        return rows
            .filter { newest.timeIntervalSince(TrendMath.day($0.snapshot.date)) <= 86_400 }
            .sorted { ($0.snapshot.stationCount ?? 0, $1.state) > ($1.snapshot.stationCount ?? 0, $0.state) }
    }

    /** "U91 averages 240.0¢ in NSW, the lowest of the four states reporting. The ACT is highest at 246.8¢." */
    static func factOfTheDay(fuel: FuelType, _ latest: [StateLatest]) -> String? {
        guard let low = latest.min(by: { $0.snapshot.avg < $1.snapshot.avg }),
              let high = latest.max(by: { $0.snapshot.avg < $1.snapshot.avg }) else { return nil }
        let lowText = "\(fuel.rawValue) averages \(TrendFormat.cents(low.snapshot.avg))¢ in \(StateName.short(low.state))"
        if latest.count == 1 { return "\(lowText) today." }
        if high.snapshot.avg == low.snapshot.avg {
            return "\(fuel.rawValue) averages \(TrendFormat.cents(low.snapshot.avg))¢ in all \(TrendFormat.word(latest.count)) states reporting."
        }
        let highName = TrendFormat.sentenceStart(StateName.short(high.state))
        return "\(lowText), the lowest of the \(TrendFormat.word(latest.count)) states reporting. \(highName) is highest at \(TrendFormat.cents(high.snapshot.avg))¢."
    }

    /** "WA has the widest gap: its cheapest station is 50.4¢ under the state average." */
    static func widestGap(_ latest: [StateLatest]) -> String? {
        guard latest.count > 1, let widest = latest.max(by: { gap($0) < gap($1) }), gap(widest) > 0 else { return nil }
        return "\(TrendFormat.sentenceStart(StateName.short(widest.state))) has the widest gap: its cheapest station is \(TrendFormat.cents(gap(widest)))¢ under the state average."
    }

    private static func gap(_ row: StateLatest) -> Double { row.snapshot.avg - row.snapshot.min }

    /** The days with no data between runs, as (first missing day, last missing day). */
    static func missingRanges(_ series: [Snapshot]) -> [(first: String, last: String)] {
        TrendMath.gaps(series).map { from, to in
            (TrendFormat.iso(from.addingTimeInterval(86_400)), TrendFormat.iso(to.addingTimeInterval(-86_400)))
        }
    }

    /** "No data 2 Aug – 17 Sep", or "No data 5 Jul" for a single day. */
    static func gapLabel(first: String, last: String) -> String {
        first == last ? "No data \(TrendFormat.dayMonth(first))"
            : "No data \(TrendFormat.dayMonth(first)) – \(TrendFormat.dayMonth(last))"
    }

    /** One y scale for small multiples: the values' span rounded out to `step`, at least one step tall. */
    static func sharedScale(_ values: [Double], step: Double = 20) -> ClosedRange<Double> {
        guard let lo = values.min(), let hi = values.max() else { return 0...step }
        let bottom = (lo / step).rounded(.down) * step
        let top = (hi / step).rounded(.up) * step
        return bottom...max(top, bottom + step)
    }

    /** Whether a series is too short to draw as a line yet. */
    static func isCollecting(_ series: [Snapshot]) -> Bool { series.count < collectingBelowDays }

    /**
     * The latest average against 7 days earlier, the first of the previous month and the first day of
     * data, each only where that exact day has data: a day inside a gap is left out rather than
     * swapped for a neighbour, and every label names the day it compares with.
     */
    static func comparisons(_ series: [Snapshot]) -> [Comparison] {
        guard let latest = series.last, let first = series.first, let p = TrendFormat.parts(latest.date) else { return [] }
        let previousMonth = p.month == 1 ? String(format: "%04d-12-01", p.year - 1) : String(format: "%04d-%02d-01", p.year, p.month - 1)
        let targets = [TrendFormat.adding(-7, to: latest.date), previousMonth, first.date]
        var seen: Set<String> = [latest.date]
        return targets.compactMap { target in
            guard seen.insert(target).inserted, let then = series.first(where: { $0.date == target }) else { return nil }
            return Comparison(date: target, change: latest.avg - then.avg)
        }
    }

    /** Today's average between the series' lowest and highest; nil without at least two different days. */
    static func rangePosition(_ series: [Snapshot]) -> RangePosition? {
        guard let today = series.last, let low = series.min(by: { $0.avg < $1.avg }),
              let high = series.max(by: { $0.avg < $1.avg }), high.avg > low.avg else { return nil }
        return RangePosition(low: low, high: high, today: today, fraction: (today.avg - low.avg) / (high.avg - low.avg))
    }

    /** "At the top of its range since June." */
    static func rangeSentence(_ position: RangePosition, since first: String) -> String {
        let since = TrendFormat.since(first)
        switch position.fraction {
        case 0.95...: return "At the top of its range since \(since)."
        case 0.66..<0.95: return "Near the top of its range since \(since)."
        case ...0.05: return "At the bottom of its range since \(since)."
        case 0.05..<0.34: return "Near the bottom of its range since \(since)."
        default: return "In the middle of its range since \(since)."
        }
    }

    /**
     * The band chart's axis: from the cheapest price, but no lower than half the averages' span under
     * the lowest average, to a third of that span above the highest average, so a few very cheap or
     * very dear stations cannot flatten the line. `BandScale.legend` names any cut.
     */
    static func bandScale(_ series: [Snapshot], step: Double = 10) -> BandScale? {
        guard let avgLo = series.map(\.avg).min(), let avgHi = series.map(\.avg).max(),
              let minLo = series.map(\.min).min(), let maxHi = series.map(\.max).max() else { return nil }
        let span = max(avgHi - avgLo, step)
        let bottom = (max(minLo, avgLo - span / 2) / step).rounded(.down) * step
        let top = (min(maxHi, avgHi + span / 3) / step).rounded(.up) * step
        let domain = bottom...max(top, bottom + step)
        return BandScale(domain: domain, cutMax: maxHi > domain.upperBound ? maxHi : nil,
                         cutMin: minLo < domain.lowerBound ? minLo : nil)
    }

    /** Every fuel's latest state average on the day the state last reported, cheapest first. */
    static func fuelRungs(_ latestByFuel: [FuelType: Snapshot]) -> [FuelRung] {
        guard let newest = latestByFuel.values.map(\.date).max() else { return [] }
        let today = latestByFuel.filter { $0.value.date == newest }
        let base = today[.u91]?.avg
        return today.map { fuel, snapshot in
            FuelRung(fuel: fuel, average: snapshot.avg, difference: base.map { snapshot.avg - $0 })
        }
        .sorted { $0.average < $1.average }
    }

    /**
     * "Premium 98 costs 23.9¢ more than U91: $13.38 on a 56 L tank." About the selected fuel, or
     * Premium 98 when U91 is selected; the tank figure only when the reader has set their tank.
     */
    static func fuelFact(_ rungs: [FuelRung], selected: FuelType, tankLitres: Int?) -> String? {
        let focus = selected == .u91 ? FuelType.u98 : selected
        guard let rung = rungs.first(where: { $0.fuel == focus }), let diff = rung.difference,
              abs(diff) >= 0.05 else { return nil }
        let head = "\(focus.spoken) costs \(TrendFormat.cents(abs(diff)))¢ \(diff > 0 ? "more" : "less") than U91"
        guard let tankLitres, tankLitres > 0 else { return "\(head)." }
        return "\(head): \(TrendFormat.dollars(abs(diff) * Double(tankLitres) / 100)) on a \(tankLitres)\u{00A0}L tank."
    }

    /** "Via NSW FuelCheck, FuelWatch and FuelCheck TAS." for the states shown (decision 0007). */
    static func credit(_ states: [String]) -> String? {
        var names: [String] = []
        for state in states {
            if let name = DataSource.forState(state)?.name, !names.contains(name) { names.append(name) }
        }
        return names.isEmpty ? nil : "Via \(TrendFormat.list(names))."
    }
}

extension FuelRung: Identifiable {
    var id: FuelType { fuel }
}
