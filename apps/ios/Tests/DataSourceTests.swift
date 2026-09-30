import Foundation
import Testing
@testable import ServoMap

/** What each state's licence makes a station page show (decision 0007). */
struct DataSourceTests {
    @Test func stationStateCodesFindTheirSourceInAnyCase() {
        #expect(DataSource.forState("NSW")?.name == "NSW FuelCheck")
        #expect(DataSource.forState("act")?.name == "NSW FuelCheck")
        #expect(DataSource.forState("xx") == nil)
    }

    @Test func creditOnlyStatesHaveNoNotice() {
        for code in ["nsw", "act", "wa", "tas", "nt"] {
            #expect(DataSource.forState(code)?.hasNotice == false, "\(code)")
        }
    }

    @Test func licensedStatesCarryTheirStatementAndSAItsReportLink() throws {
        let year = Calendar.current.component(.year, from: .now)
        let qld = try #require(DataSource.forState("qld"))
        #expect(qld.statement?.contains("State of Queensland") == true)
        #expect(qld.statement?.contains(String(year)) == true)
        #expect(qld.statement?.contains("{year}") == false)
        let sa = try #require(DataSource.forState("sa"))
        #expect(sa.hasNotice)
        #expect(sa.reportURL.flatMap(URL.init(string:)) != nil)
    }
}
