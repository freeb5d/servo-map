import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/**
 * The fill-up log as CSV (RFC 4180), oldest first, for Numbers or Excel. Dates are ISO 8601 with
 * their offset; numbers use a full stop whatever the reader's locale, so the file opens the same
 * everywhere.
 */
enum FillUpCSV {
    static let header = ["date", "station", "station_id", "brand", "fuel", "litres", "cents_per_litre", "cost_dollars", "area_average_cents"]

    static func csv(_ entries: [FillUp], timeZone: TimeZone = .current) -> String {
        let dates = ISO8601DateFormatter()
        dates.formatOptions = [.withInternetDateTime]
        dates.timeZone = timeZone
        let rows = entries.sorted { $0.date < $1.date }.map { f in
            [dates.string(from: f.date), f.stationName, f.stationID, f.brand, f.fuel.rawValue,
             number(f.litres, 2), number(f.centsPerLitre, 1), number(f.cost, 2), f.areaAverage.map { number($0, 1) } ?? ""]
        }
        return ([header] + rows).map { $0.map(field).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /** Quoted when it holds a comma, quote or line break, with its quotes doubled. */
    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func number(_ value: Double, _ decimals: Int) -> String {
        String(format: "%.\(decimals)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/** The log as a shareable file, `servomap-fill-ups.csv`. */
struct FillUpExport: Transferable {
    let entries: [FillUp]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(FillUpCSV.csv(export.entries).utf8)
        }
        .suggestedFileName("servomap-fill-ups.csv")
    }
}
