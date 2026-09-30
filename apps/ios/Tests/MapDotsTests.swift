import Testing
@testable import ServoMap

struct MapDotsTests {
    private struct Pin { let id: String; let lat: Double; let lng: Double }
    /** About 5 m of longitude per point: street level. */
    private let street = 0.00005

    private func choose(_ pins: [Pin], degreesPerPoint: Double) -> Set<String> {
        MapDots.choose(pins, id: \.id, lat: \.lat, lng: \.lng, degreesPerPoint: degreesPerPoint)
    }

    @Test func cheapestDotWinsWhereDotsOverlap() {
        // Ranked cheapest first; at street level the second is a point away and would be drawn under it.
        let cell = MapDots.cell(degreesPerPoint: street)
        let pins = [Pin(id: "cheap", lat: cell * 0.1, lng: cell * 0.1), Pin(id: "dear", lat: cell * 0.2, lng: cell * 0.3)]
        #expect(choose(pins, degreesPerPoint: street) == ["cheap"])
    }

    @Test func dotsApartAllDraw() {
        let pins = [Pin(id: "a", lat: -33.80, lng: 151.00), Pin(id: "b", lat: -33.81, lng: 151.00),
                    Pin(id: "c", lat: -33.80, lng: 151.01)]
        #expect(choose(pins, degreesPerPoint: street) == ["a", "b", "c"])
    }

    @Test func zoomingOutMergesDots() {
        let pins = [Pin(id: "a", lat: -33.80, lng: 151.00), Pin(id: "b", lat: -33.80, lng: 151.001)]
        #expect(choose(pins, degreesPerPoint: street) == ["a", "b"])
        // At about 1 km a point, 100 m apart is the same spot.
        #expect(choose(pins, degreesPerPoint: 0.01) == ["a"])
    }

    @Test func cellIsAtMostOneDotAcrossAndStepsByPowersOfTwo() {
        for scale in [0.00003, 0.0001, 0.0007, 0.004, 0.02] {
            let cell = MapDots.cell(degreesPerPoint: scale)
            #expect(cell <= MapDots.size * scale)
            #expect(cell > MapDots.size * scale / 2)
        }
        // Zooming a little does not move the grid, so the same dots stay drawn.
        #expect(MapDots.cell(degreesPerPoint: 0.00100) == MapDots.cell(degreesPerPoint: 0.00105))
    }

    @Test func aMapWithoutAScaleDrawsEveryDot() {
        let pins = [Pin(id: "a", lat: 0, lng: 0), Pin(id: "b", lat: 0, lng: 0)]
        #expect(choose(pins, degreesPerPoint: .infinity) == ["a", "b"])
        #expect(choose(pins, degreesPerPoint: 0) == ["a", "b"])
    }

    @Test func denseFieldIsBoundedByCells() {
        // 2,000 stations packed into about 0.02 degrees: at 1 km a point that is a handful of cells.
        let pins = (0..<2_000).map { i in Pin(id: "\(i)", lat: -33.8 + Double(i % 45) * 0.0004, lng: 151 + Double(i / 45) * 0.0004) }
        #expect(choose(pins, degreesPerPoint: 0.01).count <= 4)
    }
}
