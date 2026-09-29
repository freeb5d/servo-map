import Testing
@testable import ServoMap

struct PriceRangeTests {
    @Test func splitsIntoThirds() {
        let range = PriceRange([200, 210, 220, 230, 240, 250, 260, 270, 280])
        #expect(range.tier(200) == .cheap)
        #expect(range.tier(240) == .fair)
        #expect(range.tier(280) == .pricey)
    }

    @Test func emptyInputDoesNotCrash() {
        let range = PriceRange([])
        #expect(range.tier(100) == .pricey)
    }

    @Test func singlePriceIsCheap() {
        #expect(PriceRange([225.9]).tier(225.9) == .cheap)
    }
}
