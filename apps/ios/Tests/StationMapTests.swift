import MapKit
import SwiftUI
import Testing
@testable import ServoMap

/**
 * The map is skipped whenever it would draw the same, because each `Map` update lays out every
 * annotation again. These pin down what "the same" means.
 */
@MainActor
struct StationMapTests {
    private func map(selected: Station? = nil, tagged: Set<String> = ["a"], dots: Set<String>? = ["b"],
                     onSettle: @escaping (MKCoordinateRegion) -> Void = { _ in }) -> StationMap {
        StationMap(camera: .constant(.automatic), selection: .constant(selected), selected: selected,
                   placement: TagPlacement.Result(tagged: tagged, hiddenDots: []), dots: dots, onSettle: onSettle)
    }

    @Test func aNewSettleHandlerAloneDoesNotRedraw() {
        // MapReader re-runs its content, with a new closure, every time the camera settles.
        #expect(map(onSettle: { _ in }) == map(onSettle: { _ in _ = 1 }))
    }

    @Test func newTagsOrDotsRedraw() {
        #expect(map(tagged: ["a"]) != map(tagged: ["a", "c"]))
        #expect(map(dots: ["b"]) != map(dots: ["b", "d"]))
        #expect(map(dots: nil) != map(dots: ["b"]))
    }

    @Test func pickingAStationRedraws() {
        #expect(map(selected: nil) != map(selected: Fixture.station("a")))
        #expect(map(selected: Fixture.station("a")) == map(selected: Fixture.station("a")))
    }
}
