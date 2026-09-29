import Foundation

/** Reads over the daily state series, mirroring packages/web/src/lib/trends.ts. */
enum TrendMath {
    static func day(_ date: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: date) ?? .distantPast
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
