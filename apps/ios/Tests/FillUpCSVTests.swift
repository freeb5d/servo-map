import Foundation
import Testing
@testable import ServoMap

struct FillUpCSVTests {
    private let utc = TimeZone(identifier: "UTC")!

    private func fill(_ iso: String, station: String = "Metro Fuel Glebe", litres: Double = 40, price: Double = 225.9, avg: Double? = 240) -> FillUp {
        FillUp(date: ISO8601DateFormatter().date(from: iso)!, stationID: "nsw-1", stationName: station, brand: "Metro Fuel",
               fuel: .u91, litres: litres, centsPerLitre: price, areaAverage: avg)
    }

    @Test func headerOnlyForAnEmptyLog() {
        #expect(FillUpCSV.csv([], timeZone: utc)
                == "date,station,station_id,brand,fuel,litres,cents_per_litre,cost_dollars,area_average_cents\r\n")
    }

    @Test func rowsOldestFirstWithFixedDecimals() {
        let csv = FillUpCSV.csv([fill("2026-09-23T08:30:00Z", litres: 42.3, price: 225.9, avg: 240.3),
                                 fill("2026-09-01T18:05:00Z", litres: 30, price: 230, avg: nil)], timeZone: utc)
        let lines = csv.components(separatedBy: "\r\n")
        #expect(lines.count == 4)          // header, two rows, and the empty string after the last CRLF
        #expect(lines[1] == "2026-09-01T18:05:00Z,Metro Fuel Glebe,nsw-1,Metro Fuel,U91,30.00,230.0,69.00,")
        #expect(lines[2] == "2026-09-23T08:30:00Z,Metro Fuel Glebe,nsw-1,Metro Fuel,U91,42.30,225.9,95.56,240.3")
        #expect(lines[3].isEmpty)
    }

    @Test func datesCarryTheirOffset() {
        let sydney = TimeZone(identifier: "Australia/Sydney")!
        let csv = FillUpCSV.csv([fill("2026-09-23T08:30:00Z")], timeZone: sydney)
        #expect(csv.contains("2026-09-23T18:30:00+10:00,"))
    }

    @Test func fieldsWithCommasOrQuotesAreQuoted() {
        #expect(FillUpCSV.field("Shell, Glebe") == "\"Shell, Glebe\"")
        #expect(FillUpCSV.field("Joe's \"Fuel\"") == "\"Joe's \"\"Fuel\"\"\"")
        #expect(FillUpCSV.field("Two\nlines") == "\"Two\nlines\"")
        #expect(FillUpCSV.field("Plain") == "Plain")
        let csv = FillUpCSV.csv([fill("2026-09-23T08:30:00Z", station: "Shell, Glebe")], timeZone: utc)
        #expect(csv.contains(",\"Shell, Glebe\",nsw-1,"))
    }
}
