import CoreGraphics
import Testing
@testable import ServoMap

struct MapFramingTests {
    private let screen = CGSize(width: 402, height: 874)

    @Test func withoutTheSheetTheMapAboveTheTabBarIsVisible() {
        let visible = MapFraming.visible(size: screen, bottomInset: 140, sheetUp: false)
        #expect(visible.minY == MapFraming.topControls)
        #expect(abs(visible.maxY - (874 - 140)) < 0.001)
        #expect(visible.width == 402)
    }

    @Test func withTheSheetUpOnlyTheTopPartIsVisible() {
        let visible = MapFraming.visible(size: screen, bottomInset: 140, sheetUp: true)
        #expect(abs(visible.maxY - 874 * 0.46) < 0.001)
    }

    @Test func noSizeMeansNothingVisible() {
        #expect(MapFraming.visible(size: .zero, bottomInset: 0, sheetUp: false).height == 0)
    }

    @Test func aBoxFillingTheWholeMapIsCentred() {
        let r = MapFraming.region(showing: -33.9, 151.2, latDelta: 0.1, lngDelta: 0.1,
                                  in: CGRect(origin: .zero, size: screen), of: screen)
        #expect(r == MapFraming.Region(lat: -33.9, lng: 151.2, latDelta: 0.1, lngDelta: 0.1))
    }

    @Test func aBoxShownInTheTopHalfPutsTheCameraSouthOfIt() {
        let top = CGRect(x: 0, y: 0, width: screen.width, height: screen.height / 2)
        let r = MapFraming.region(showing: -33.9, 151.2, latDelta: 0.1, lngDelta: 0.1, in: top, of: screen)
        // Twice the span, and the box's centre a quarter of the map above the camera's.
        #expect(abs(r.latDelta - 0.2) < 1e-9)
        #expect(abs(r.lngDelta - 0.1) < 1e-9)
        #expect(abs(r.lat - (-33.9 - 0.05)) < 1e-9)
        #expect(abs(r.lng - 151.2) < 1e-9)
    }

    @Test func anEmptyVisiblePartLeavesTheBoxAsIs() {
        let r = MapFraming.region(showing: -33.9, 151.2, latDelta: 0.1, lngDelta: 0.1, in: .zero, of: screen)
        #expect(r == MapFraming.Region(lat: -33.9, lng: 151.2, latDelta: 0.1, lngDelta: 0.1))
    }
}
