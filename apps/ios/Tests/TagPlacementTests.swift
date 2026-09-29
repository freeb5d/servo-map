import CoreGraphics
import Testing
@testable import ServoMap

struct TagPlacementTests {
    private struct Pin { let id: String; let point: CGPoint? }
    private let screen = CGRect(x: 0, y: 0, width: 400, height: 400)

    private func choose(_ pins: [Pin], limit: Int = 12) -> Set<String> {
        TagPlacement.choose(pins, id: \.id, point: \.point, visible: screen, limit: limit).tagged
    }

    @Test func cheapestWinsWhenTagsCollide() {
        let pins = [Pin(id: "cheap", point: CGPoint(x: 100, y: 100)), Pin(id: "near", point: CGPoint(x: 130, y: 105))]
        #expect(choose(pins) == ["cheap"])
    }

    @Test func farApartTagsBothShow() {
        let pins = [Pin(id: "a", point: CGPoint(x: 100, y: 100)), Pin(id: "b", point: CGPoint(x: 300, y: 300))]
        #expect(choose(pins) == ["a", "b"])
    }

    @Test func offscreenAndUnprojectablePointsAreSkipped() {
        let pins = [Pin(id: "off", point: CGPoint(x: 900, y: 100)), Pin(id: "none", point: nil), Pin(id: "on", point: CGPoint(x: 50, y: 50))]
        #expect(choose(pins) == ["on"])
    }

    @Test func tagsMustFitWhollyOnScreen() {
        // The point is visible but the tag would hang off the right edge.
        #expect(choose([Pin(id: "edge", point: CGPoint(x: 390, y: 100))]).isEmpty)
    }

    @Test func dotsUnderATagAreHidden() {
        let pins = [Pin(id: "tag", point: CGPoint(x: 200, y: 200)), Pin(id: "under", point: CGPoint(x: 190, y: 188)),
                    Pin(id: "clear", point: CGPoint(x: 60, y: 350))]
        let result = TagPlacement.choose(pins, id: \.id, point: \.point, visible: screen, limit: 1)
        #expect(result.tagged == ["tag"])
        #expect(result.hiddenDots == ["under"])
    }

    @Test func respectsTheLimit() {
        let pins = (0..<10).map { Pin(id: "\($0)", point: CGPoint(x: 40, y: 30 + $0 * 36)) }
        #expect(choose(pins, limit: 3) == ["0", "1", "2"])
    }
}
