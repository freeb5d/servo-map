import CoreGraphics
import Foundation

/**
 * Camera maths for the map behind the tab bar: what part of it the reader can see, and where to
 * put the camera so a place lands in that part. Pure, so the layout is tested without a map.
 */
enum MapFraming {
    /** A camera: centre and span in degrees. */
    struct Region: Equatable {
        var lat: Double, lng: Double, latDelta: Double, lngDelta: Double
    }

    /** Height of the fuel switch and map controls across the top of the map. */
    static let topControls: CGFloat = 70

    /**
     * The part of a map of `size` that no chrome covers. With the results sheet up, the map above
     * the sheet's half height; otherwise everything above the tab bar and its accessory, which
     * the map reports as its bottom safe-area inset.
     */
    static func visible(size: CGSize, bottomInset: CGFloat, sheetUp: Bool) -> CGRect {
        let bottom = sheetUp ? size.height * 0.46 : size.height - bottomInset
        return CGRect(x: 0, y: topControls, width: size.width, height: max(0, bottom - topControls))
    }

    /**
     * The camera that shows a box of `latDelta` by `lngDelta` degrees around (`lat`, `lng`) filling
     * `visible`, a part of a map of `size`. The span grows by the map's share of the visible part,
     * and the centre moves by the visible part's offset from the map's middle, so the box lands in it.
     */
    static func region(showing lat: Double, _ lng: Double, latDelta: Double, lngDelta: Double,
                       in visible: CGRect, of size: CGSize) -> Region {
        guard visible.width > 0, visible.height > 0, size.width > 0, size.height > 0 else {
            return Region(lat: lat, lng: lng, latDelta: latDelta, lngDelta: lngDelta)
        }
        let totalLat = latDelta * size.height / visible.height
        let totalLng = lngDelta * size.width / visible.width
        // Screen y grows downward and latitude upward: a box drawn above the middle needs a camera south of it.
        let centreLat = lat - (size.height / 2 - visible.midY) * totalLat / size.height
        let centreLng = lng + (size.width / 2 - visible.midX) * totalLng / size.width
        return Region(lat: centreLat, lng: centreLng, latDelta: totalLat, lngDelta: totalLng)
    }
}
