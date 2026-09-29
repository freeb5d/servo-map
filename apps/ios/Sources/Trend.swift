import Foundation

/** Reads over the daily state series, mirroring packages/web/src/lib/trends.ts. */
enum TrendMath {
    /**
     * Midnight UTC of a "yyyy-MM-dd" date. Parsed by hand: it runs for every point of every chart on
     * each redraw, and a DateFormatter per call made the Trends screen take ~130 ms a frame.
     */
    static func day(_ date: String) -> Date {
        let parts = date.split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), (1...31).contains(d) else { return .distantPast }
        return Date(timeIntervalSince1970: Double(daysFromCivil(y, m, d)) * 86_400)
    }

    /** Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's days_from_civil). */
    private static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /** Runs of consecutive days; a missing day starts a new run so charts never bridge a gap. */
    static func runs(_ series: [Snapshot]) -> [[Snapshot]] {
        var out: [[Snapshot]] = []
        for s in series {
            if let last = out.last?.last, day(s.date).timeIntervalSince(day(last.date)) <= 86_400 * 1.5 {
                out[out.count - 1].append(s)
            } else {
                out.append([s])
            }
        }
        return out
    }

    /** Gaps between runs as (last day with data, next day with data). */
    static func gaps(_ series: [Snapshot]) -> [(Date, Date)] {
        let r = runs(series)
        return zip(r, r.dropFirst()).map { (day($0.last!.date), day($1.first!.date)) }
    }

    static func verdict(_ series: [Snapshot]) -> String? {
        guard let latest = series.last, let lo = series.map(\.avg).min(), let hi = series.map(\.avg).max(), hi > lo else { return nil }
        // Plain hyphen: the bundled gothic has no non-breaking hyphen, and a fallback glyph renders spaced out.
        let days = "\(Int(day(latest.date).timeIntervalSince(day(series[0].date)) / 86_400) + 1)-day"
        let position = (latest.avg - lo) / (hi - lo)
        if latest.avg == hi { return "At the \(days) high." }
        if position >= 0.66 { return "Near the \(days) high." }
        if position <= 0.33 { return "Near the \(days) low." }
        return "Mid-range for the last \(days)s."
    }

    /** Change in the average against the snapshot `days` earlier, or nil when that day is missing. */
    static func change(_ series: [Snapshot], days: Int) -> Double? {
        guard let latest = series.last else { return nil }
        let target = day(latest.date).addingTimeInterval(Double(-days) * 86_400)
        guard let earlier = series.last(where: { day($0.date) <= target }),
              day(earlier.date).timeIntervalSince(target) > -86_400 * 1.5 else { return nil }
        return latest.avg - earlier.avg
    }

    /** The last `days` days of the series (all of it when nil). */
    static func window(_ series: [Snapshot], days: Int?) -> [Snapshot] {
        guard let days, let latest = series.last else { return series }
        let start = day(latest.date).addingTimeInterval(Double(-days) * 86_400)
        return series.filter { day($0.date) > start }
    }

    /** Average price per weekday, Monday first. */
    static func weekdays(_ series: [Snapshot]) -> [(String, Double?)] {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var sums = Array(repeating: (0.0, 0), count: 7)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        for s in series {
            let i = (cal.component(.weekday, from: day(s.date)) + 5) % 7
            sums[i].0 += s.avg
            sums[i].1 += 1
        }
        return zip(names, sums).map { ($0, $1.1 == 0 ? nil : $1.0 / Double($1.1)) }
    }
}
