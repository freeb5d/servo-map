import Testing
@testable import ServoMap

struct NamesTests {
    @Test(arguments: [
        ("CROYDON", "Croydon"),
        ("6 DOYLE RD, REVESBY NSW 2212", "6 Doyle Rd, Revesby NSW 2212"),
        ("97A HUME HWY", "97A Hume Hwy"),
        ("7-ELEVEN YAGOONA", "7-Eleven Yagoona"),
        ("O'CONNELL", "O'Connell"),
        ("BP CAMPERDOWN", "BP Camperdown"),
        ("McMahons Point", "McMahons Point"),
    ])
    func titleCases(input: String, expected: String) {
        #expect(titleCasePlace(input) == expected)
    }

    @Test func addressDoesNotRepeatSuburb() {
        let s = Fixture.station("a")
        #expect(s.addressLine == "1 Test St, Croydon NSW 2132")
    }

    @Test func brandFamiliesResolve() {
        #expect(BrandFamily.resolve("EG Ampol").id == "ampol")
        #expect(BrandFamily.resolve("Reddy Express").id == "shell")
        #expect(BrandFamily.resolve("Bribbaree Servo").id == "independent")
    }
}
