import CoreGraphics

/**
 * Chooses which stations get a full price tag: cheapest first, skipping any tag that would
 * overlap one already placed or not fit wholly inside the visible part of the map. Dots that
 * would sit under a tag are hidden, because MapKit does not promise to draw tags above them.
 */
enum TagPlacement {
    /** Approximate footprint of a tag (seal cell + price), drawn above its point. */
    static let tagSize = CGSize(width: 76, height: 20)

    struct Result: Equatable {
        var tagged: Set<String> = []
        var hiddenDots: Set<String> = []
    }

    static func choose<Item>(
        _ ranked: [Item],
        id: (Item) -> String,
        point: (Item) -> CGPoint?,
        visible: CGRect,
        limit: Int = 12,
        size: CGSize = tagSize
    ) -> Result {
        var placed: [CGRect] = []
        var result = Result()
        for item in ranked where result.tagged.count < limit {
            guard let p = point(item) else { continue }
            // Tags are anchored at their bottom centre (see MapScreen), so they sit just above the point.
            let rect = CGRect(x: p.x - size.width / 2, y: p.y - size.height, width: size.width, height: size.height)
            guard visible.contains(rect) else { continue }
            // A little breathing room so neighbouring tags never touch.
            if placed.contains(where: { $0.insetBy(dx: -4, dy: -3).intersects(rect) }) { continue }
            placed.append(rect)
            result.tagged.insert(id(item))
        }
        for item in ranked where !result.tagged.contains(id(item)) {
            if let p = point(item), placed.contains(where: { $0.insetBy(dx: -5, dy: -5).contains(p) }) {
                result.hiddenDots.insert(id(item))
            }
        }
        return result
    }
}
