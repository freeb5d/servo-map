import Testing
@testable import ServoMap

struct NamesTests {
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
