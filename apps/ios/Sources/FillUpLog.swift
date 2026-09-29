import Foundation
import Observation

/** One fill-up the user recorded. Prices are cents per litre; the area average is captured at the time. */
struct FillUp: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var date: Date
    var stationID: String
    var stationName: String
    var brand: String
    var fuel: FuelType
    var litres: Double
    var centsPerLitre: Double
    /** Local average when logged; nil if it was unknown, in which case no saving is claimed. */
    var areaAverage: Double?

    var cost: Double { litres * centsPerLitre / 100 }
    /** Dollars saved against the area average; never negative, a dearer fill counts as zero saved. */
    var saved: Double { areaAverage.map { max(0, ($0 - centsPerLitre) * litres / 100) } ?? 0 }
}

/** Totals for one calendar month of fill-ups. */
struct MonthSummary: Equatable, Sendable {
    var count = 0
    var litres = 0.0
    var spent = 0.0
    var saved = 0.0

    /** Summary of the fill-ups in the same calendar month as `month`. */
    static func of(_ log: [FillUp], month: Date, calendar: Calendar = .current) -> MonthSummary {
        log.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
            .reduce(into: MonthSummary()) { s, f in
                s.count += 1
                s.litres += f.litres
                s.spent += f.cost
                s.saved += f.saved
            }
    }
}

extension MonthSummary {
    /** The `count` calendar months ending with the month of `now`, oldest first; empty months included. */
    static func recent(_ log: [FillUp], months count: Int, now: Date, calendar: Calendar = .current) -> [(month: Date, summary: MonthSummary)] {
        guard let start = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<count).reversed().compactMap { back in
            calendar.date(byAdding: .month, value: -back, to: start).map { ($0, of(log, month: $0, calendar: calendar)) }
        }
    }
}

/** Habits across the whole log, for the figures on the Log page. */
struct LogHabits: Equatable, Sendable {
    var averageLitres: Double
    /** Litre-weighted average price paid, cents per litre. */
    var averagePrice: Double
    /** Mean of (local average − price paid) over fills with a known average; positive means paid under. */
    var averageUnder: Double?
    /** Mean days between consecutive fills; nil with fewer than two. */
    var daysBetween: Double?
    /** The station filled at most often and how many times; ties go to the most recent. */
    var favourite: (name: String, count: Int)?

    static func of(_ log: [FillUp]) -> LogHabits? {
        guard !log.isEmpty else { return nil }
        let litres = log.map(\.litres).reduce(0, +)
        let paid = log.map { $0.litres * $0.centsPerLitre }.reduce(0, +)
        let unders = log.compactMap { f in f.areaAverage.map { $0 - f.centsPerLitre } }
        let dates = log.map(\.date).sorted()
        let gaps = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) / 86_400 }
        let newestFirst = log.sorted { $0.date > $1.date }.map(\.stationName)
        let recency = { (name: String) in newestFirst.firstIndex(of: name) ?? .max }
        let favourite = Dictionary(grouping: log, by: \.stationName).mapValues(\.count)
            .max { a, b in a.value != b.value ? a.value < b.value : recency(a.key) > recency(b.key) }
        return LogHabits(
            averageLitres: litres / Double(log.count),
            averagePrice: litres > 0 ? paid / litres : 0,
            averageUnder: unders.isEmpty ? nil : unders.reduce(0, +) / Double(unders.count),
            daysBetween: gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count),
            favourite: favourite.map { ($0.key, $0.value) })
    }

    static func == (a: LogHabits, b: LogHabits) -> Bool {
        a.averageLitres == b.averageLitres && a.averagePrice == b.averagePrice && a.averageUnder == b.averageUnder
            && a.daysBetween == b.daysBetween && a.favourite?.name == b.favourite?.name && a.favourite?.count == b.favourite?.count
    }
}

/** The fill-up log, kept as JSON in the app's documents folder; nothing leaves the device. */
@MainActor @Observable
final class FillUpLog {
    private(set) var entries: [FillUp] = []
    private let url: URL?

    init(url: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appending(path: "fill-ups.json")) {
        self.url = url
        if let url, let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode([FillUp].self, from: data) {
            entries = saved.sorted { $0.date > $1.date }
        }
    }

    func add(_ fillUp: FillUp) {
        entries.insert(fillUp, at: 0)
        entries.sort { $0.date > $1.date }
        persist()
    }

    func remove(_ ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        persist()
    }

    private func persist() {
        guard let url, let data = try? JSONEncoder().encode(entries) else { return }
        // Written atomically so a crash mid-save cannot leave a half file behind.
        try? data.write(to: url, options: .atomic)
    }
}
