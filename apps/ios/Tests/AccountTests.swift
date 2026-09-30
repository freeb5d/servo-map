import Foundation
import Testing
@testable import ServoMap

@MainActor
struct AccountTests {
    @Test func vehicleDecodesFromTheCatalogue() throws {
        let json = #"[{"id":"toyota-corolla-2019","make":"Toyota","model":"Corolla","fromYear":2019,"body":"hatch","fuel":"U91","tankLitres":50,"source":"https://example.com"}]"#
        let v = try JSONDecoder().decode([Vehicle].self, from: Data(json.utf8))[0]
        #expect(v.name == "Toyota Corolla")
        #expect(v.years == "2019–")
        #expect(v.bodyType == .hatch)
        #expect(v.fuelType == .u91)
        #expect(v.toYear == nil)
    }

    @Test func fillUpRoundTripsThroughTheWireFormat() throws {
        let f = FillUp(date: Date(timeIntervalSince1970: 1_790_000_000), stationID: "nsw-1", stationName: "Metro", brand: "Metro Fuel",
                       fuel: .u91, litres: 42.3, centsPerLitre: 225.9, areaAverage: 240.3)
        let back = try #require(FillUp(f.dto))
        #expect(back == f)
        #expect(FillUp(FillUpDTO(id: "not-a-uuid", date: f.dto.date, stationId: "x", stationName: "x", brand: "x", fuel: "U91", litres: 1, centsPerLitre: 200, areaAverage: nil)) == nil)
    }

    @Test func mergingAddsOnlyNewFillUps() {
        let url = FileManager.default.temporaryDirectory.appending(path: "merge-\(UUID()).json")
        let log = FillUpLog(url: url)
        let mine = FillUp(date: .now, stationID: "a", stationName: "A", brand: "BP", fuel: .u91, litres: 40, centsPerLitre: 220, areaAverage: nil)
        log.add(mine)
        let theirs = FillUp(date: .now.addingTimeInterval(-86_400), stationID: "b", stationName: "B", brand: "BP", fuel: .u91, litres: 30, centsPerLitre: 230, areaAverage: nil)
        #expect(log.merge([mine, theirs]) == 1)
        #expect(log.merge([mine, theirs]) == 0)
        #expect(log.entries.map(\.id) == [mine.id, theirs.id])
    }

    @Test func initialsComeFromTheNameOrEmail() {
        let store = AccountStore()
        store.signOut()
        #expect(store.initials == nil)
        #expect(store.displayName == "You")
    }
}
