import CoreGraphics
import Foundation

/**
 * Chooses which stations the map draws as dots. Every annotation is a hosted SwiftUI view that
 * MapKit re-lays out on each map update, so an update costs more the more dots are on screen:
 * with hundreds, each one held the main thread for 100 ms or more, and the map and its tags
 * stalled and drifted apart for a moment whenever the camera settled.
 *
 * Only the cheapest dot in each dot-sized cell is drawn; the others would sit under it. The grid
 * is fixed to the map, not the screen, and its cell size steps only by powers of two as the map
 * zooms, so panning never changes which dots are drawn and does not cost a map update of its own.
 */
enum MapDots {
    /** Diameter of a map dot, in points. */
    static let size: CGFloat = 9

    /**
     * IDs of the `ranked` items (cheapest first) worth drawing as dots, on a map where one point
     * spans `degreesPerPoint` of longitude.
     */
    static func choose<Item>(
        _ ranked: [Item],
        id: (Item) -> String,
        lat: (Item) -> Double,
        lng: (Item) -> Double,
        degreesPerPoint: Double
    ) -> Set<String> {
        // A map that has not reported its scale yet draws every dot.
        guard degreesPerPoint.isFinite, degreesPerPoint > 0 else { return Set(ranked.map(id)) }
        let side = cell(degreesPerPoint: degreesPerPoint)
        var taken = Set<Cell>()
        var kept = Set<String>()
        for item in ranked {
            let c = Cell(x: Int((lng(item) / side).rounded(.down)), y: Int((lat(item) / side).rounded(.down)))
            if taken.insert(c).inserted { kept.insert(id(item)) }
        }
        return kept
    }

    /**
     * The cell's side in degrees: the largest power of two no wider than a dot, so a cell is
     * between half a dot and one dot across and only dots that overlap share one.
     */
    static func cell(degreesPerPoint: Double) -> Double {
        exp2(log2(Double(size) * degreesPerPoint).rounded(.down))
    }

    private struct Cell: Hashable { let x: Int, y: Int }
}
