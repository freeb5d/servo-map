import Foundation

/**
 * Figures and dates as Trends prints them. Dates are the API's "yyyy-MM-dd" strings, formatted by
 * hand so the words do not change with the device's locale or time zone.
 */
enum TrendFormat {
    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let longMonths = ["January", "February", "March", "April", "May", "June", "July", "August",
                                     "September", "October", "November", "December"]

    /** 240.0 */
    static func cents(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1)).grouping(.never)) }

    /** +42.8 or −0.6, with a true minus sign as the artboards set it; no change is plain 0.0. */
    static func signed(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == 0 { return cents(0) }
        return rounded < 0 ? "−\(cents(-rounded))" : "+\(cents(rounded))"
    }

    /** 13.38 as "$13.38". */
    static func dollars(_ value: Double) -> String {
        value.formatted(.currency(code: "AUD").precision(.fractionLength(2)).locale(Locale(identifier: "en_AU")))
    }

    /** "2026-09-23" as (2026, 9, 23); nil when malformed. */
    static func parts(_ date: String) -> (year: Int, month: Int, day: Int)? {
        let p = date.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
        return (p[0], p[1], p[2])
    }

    /** "23 Sep" */
    static func dayMonth(_ date: String) -> String {
        guard let p = parts(date) else { return date }
        return "\(p.day) \(shortMonths[p.month - 1])"
    }

    /** "30 September" */
    static func dayLongMonth(_ date: String) -> String {
        guard let p = parts(date) else { return date }
        return "\(p.day) \(longMonths[p.month - 1])"
    }

    /** "June" */
    static func month(_ date: String) -> String {
        guard let p = parts(date) else { return date }
        return longMonths[p.month - 1]
    }

    /** "June" when the date is the 1st of its month, otherwise "18 Sep": what "since …" reads best as. */
    static func since(_ date: String) -> String {
        guard let p = parts(date) else { return date }
        return p.day == 1 ? longMonths[p.month - 1] : dayMonth(date)
    }

    /** The "yyyy-MM-dd" day `days` after `date` (negative for before). */
    static func adding(_ days: Int, to date: String) -> String {
        iso(TrendMath.day(date).addingTimeInterval(Double(days) * 86_400))
    }

    /** A UTC-midnight date back as "yyyy-MM-dd". */
    static func iso(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /** The reader's calendar date as "yyyy-MM-dd". */
    static func today(_ now: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /** "a", "a and b", "a, b and c". */
    static func list(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
    }

    /** Small counts as words, the way the fact sentences read ("the four states reporting"). */
    static func word(_ n: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return n < words.count ? words[n] : "\(n)"
    }

    /** "1 day", "12 days". */
    static func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }

    /** First letter upper-cased, for a name that opens a sentence ("the ACT" → "The ACT"). */
    static func sentenceStart(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }
}

/** How a state is named: its code on scales and chips, a short name in sentences, the full name in headings. */
enum StateName {
    static func code(_ state: String) -> String { state.uppercased() }

    /** "NSW", "WA", "Tasmania", "the ACT". */
    static func short(_ state: String) -> String {
        switch state.lowercased() {
        case "tas": "Tasmania"
        case "vic": "Victoria"
        case "qld": "Queensland"
        case "act": "the ACT"
        case "nt": "the NT"
        default: state.uppercased()
        }
    }

    /** "New South Wales". */
    static func full(_ state: String) -> String {
        switch state.lowercased() {
        case "nsw": "New South Wales"
        case "wa": "Western Australia"
        case "tas": "Tasmania"
        case "act": "Australian Capital Territory"
        case "vic": "Victoria"
        case "qld": "Queensland"
        case "sa": "South Australia"
        case "nt": "Northern Territory"
        default: state.uppercased()
        }
    }
}

extension FuelType {
    /** The name in a sentence: "Premium 98 costs …". */
    var spoken: String {
        switch self {
        case .u95: "Premium 95"
        case .u98: "Premium 98"
        default: rawValue
        }
    }
}
