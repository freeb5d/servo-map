import Foundation
import Testing
@testable import ServoMap

/** A station the server now reports under a new id keeps its saved slot and its fill-ups. */
@MainActor
struct StationRenameTests {
    @Test func savedStationAdoptsTheNewIDInPlace() {
        let before = UserDefaults.standard.stringArray(forKey: "saved")
        defer { UserDefaults.standard.set(before, forKey: "saved") }
        let store = Store(stations: [])
        store.savedIDs = ["nsw-1", "nsw-2", "nsw-3"]
        store.adoptStationID("nsw-2", as: "act-2")
        #expect(store.savedIDs == ["nsw-1", "act-2", "nsw-3"])
    }

    @Test func adoptingAnIDAlreadySavedKeepsOneCopy() {
        let before = UserDefaults.standard.stringArray(forKey: "saved")
        defer { UserDefaults.standard.set(before, forKey: "saved") }
        let store = Store(stations: [])
        store.savedIDs = ["act-2", "nsw-2"]
        store.adoptStationID("nsw-2", as: "act-2")
        #expect(store.savedIDs == ["act-2"])
        store.adoptStationID("nsw-9", as: "act-9")
        #expect(store.savedIDs == ["act-2"])
    }

    @Test func fillUpsFollowTheRenameAndPersist() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "log-\(UUID()).json")
        let log = FillUpLog(url: url)
        let at = { (id: String) in
            FillUp(date: .now, stationID: id, stationName: "Metro", brand: "Metro Fuel", fuel: .u91, litres: 40, centsPerLitre: 220, areaAverage: nil)
        }
        log.add(at("nsw-2"))
        log.add(at("nsw-1"))
        let moved = log.renameStation("nsw-2", to: "act-2")
        #expect(moved.map(\.stationID) == ["act-2"])
        #expect(FillUpLog(url: url).entries.map(\.stationID).sorted() == ["act-2", "nsw-1"])
        #expect(log.renameStation("nsw-2", to: "nsw-2").isEmpty)
    }
}
