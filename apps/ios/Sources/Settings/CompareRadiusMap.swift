import SwiftUI

/**
 * A small drawing for "Compare within": a paper map ground with home at the centre, a dashed ring
 * that grows and shrinks with the radius, and a few tier-coloured dots, the same every time. It is
 * an illustration, not a map of real stations; the caption above it carries the real count.
 */
struct CompareRadiusMap: View {
    let km: Int

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let fill = CompareRing.fillRadius(in: size)
            let ring = CompareRing.radius(km: km, fill: fill)
            ZStack {
                MapGround()
                Circle()
                    .fill(ServoMapColor.ink.opacity(0.05))
                    .overlay(Circle().strokeBorder(ServoMapColor.ink.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    .frame(width: ring * 2, height: ring * 2)
                    .position(centre)
                ForEach(CompareRing.dots.indices, id: \.self) { i in
                    let dot = CompareRing.dots[i]
                    let inside = CompareRing.isInside(dot, ringRadius: ring, fill: fill)
                    Circle()
                        .fill(inside ? dot.tier.color : ServoMapColor.ink3)
                        .opacity(inside ? 1 : 0.3)
                        .frame(width: 6, height: 6)
                        .position(x: centre.x + dot.x * fill, y: centre.y + dot.y * fill)
                }
                Circle()
                    .fill(ServoMapColor.ink)
                    .overlay(Circle().strokeBorder(ServoMapColor.surface, lineWidth: 2.5))
                    .frame(width: 14, height: 14)
                    .position(centre)
            }
            .animation(ServoMapMotion.standard, value: km)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: ServoMapRadius.r3))
        .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r3).strokeBorder(ServoMapColor.line, lineWidth: ServoMapList.hairline))
        .accessibilityHidden(true)
    }
}

/** The drawing's fixed scale and its decorative dots. Pure, so the scale is tested. */
enum CompareRing {
    /** A dot at (`x`, `y`) in units of the 50 km ring's radius from home, in a fixed tier. */
    struct Dot: Equatable {
        let x: Double, y: Double
        let tier: PriceTier
    }

    /** The largest choice, which fills the frame. */
    static let fullKm = 50

    /** The 50 km ring's radius: to the frame's shorter half, less a margin. */
    static func fillRadius(in size: CGSize) -> CGFloat {
        max(0, min(size.width, size.height) / 2 - 8)
    }

    /**
     * The ring's radius for `km` on a fixed scale: its area follows the distance, so 50 km fills the
     * frame and 2 km is small but still clear of the home dot (a linear scale would hide it there).
     */
    static func radius(km: Int, fill: CGFloat) -> CGFloat {
        fill * CGFloat((Double(max(0, min(km, fullKm))) / Double(fullKm)).squareRoot())
    }

    static func isInside(_ dot: Dot, ringRadius: CGFloat, fill: CGFloat) -> Bool {
        (dot.x * dot.x + dot.y * dot.y).squareRoot() * fill <= ringRadius
    }

    /** Placed by hand at every distance, so each choice takes in a few more. */
    static let dots: [Dot] = [
        Dot(x: 0.12, y: -0.08, tier: .cheap), Dot(x: -0.14, y: 0.1, tier: .fair), Dot(x: 0.05, y: 0.17, tier: .pricey),
        Dot(x: -0.26, y: -0.12, tier: .cheap), Dot(x: 0.28, y: 0.1, tier: .fair), Dot(x: 0.2, y: -0.27, tier: .pricey),
        Dot(x: -0.08, y: -0.35, tier: .fair), Dot(x: -0.38, y: 0.24, tier: .cheap), Dot(x: 0.42, y: -0.1, tier: .pricey),
        Dot(x: 0.1, y: 0.45, tier: .cheap), Dot(x: -0.5, y: -0.3, tier: .fair), Dot(x: 0.55, y: 0.3, tier: .fair),
        Dot(x: -0.3, y: 0.55, tier: .pricey), Dot(x: 0.35, y: -0.6, tier: .cheap), Dot(x: -0.68, y: 0.05, tier: .pricey),
        Dot(x: 0.72, y: -0.35, tier: .cheap), Dot(x: -0.2, y: -0.8, tier: .fair), Dot(x: 0.25, y: 0.82, tier: .pricey),
        Dot(x: -0.85, y: -0.4, tier: .cheap), Dot(x: 0.9, y: 0.2, tier: .fair), Dot(x: -0.6, y: 0.75, tier: .fair),
        Dot(x: 1.3, y: -0.6, tier: .pricey), Dot(x: -1.35, y: 0.45, tier: .cheap), Dot(x: 1.5, y: 0.7, tier: .fair),
        Dot(x: -1.55, y: -0.75, tier: .pricey),
    ]
}

/** Paper land, a strip of water and a few roads, in the map tokens. */
private struct MapGround: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ServoMapColor.mapLand))
            var water = Path()
            water.move(to: CGPoint(x: w * 0.72, y: 0))
            water.addCurve(to: CGPoint(x: w * 0.8, y: h * 0.5), control1: CGPoint(x: w * 0.76, y: h * 0.2), control2: CGPoint(x: w * 0.7, y: h * 0.35))
            water.addCurve(to: CGPoint(x: w * 0.92, y: h), control1: CGPoint(x: w * 0.88, y: h * 0.62), control2: CGPoint(x: w * 0.84, y: h * 0.85))
            water.addLine(to: CGPoint(x: w, y: h))
            water.addLine(to: CGPoint(x: w, y: 0))
            water.closeSubpath()
            context.fill(water, with: .color(ServoMapColor.mapWater))
            let roads: [[CGPoint]] = [
                [CGPoint(x: 0, y: h * 0.62), CGPoint(x: w * 0.5, y: h * 0.52), CGPoint(x: w, y: h * 0.4)],
                [CGPoint(x: w * 0.44, y: 0), CGPoint(x: w * 0.5, y: h * 0.52), CGPoint(x: w * 0.56, y: h)],
                [CGPoint(x: 0, y: h * 0.25), CGPoint(x: w * 0.32, y: h * 0.4), CGPoint(x: w * 0.5, y: h * 0.52), CGPoint(x: w * 0.7, y: h)],
                [CGPoint(x: w * 0.1, y: h), CGPoint(x: w * 0.26, y: h * 0.72), CGPoint(x: w * 0.5, y: h * 0.52)],
            ]
            for (i, points) in roads.enumerated() {
                var road = Path()
                road.addLines(points)
                context.stroke(road, with: .color(ServoMapColor.surface), style: StrokeStyle(lineWidth: i < 2 ? 5 : 3, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/** Stations counted by "Compare within": those the map already holds, around the tier centre. */
enum CompareRadius {
    static func inside(_ stations: [Station], fuel: FuelType, around centre: (lat: Double, lng: Double), km: Int) -> [Station] {
        stations.filter { $0.price(fuel) != nil && Store.distanceKm(centre, ($0.lat, $0.lng)) <= Double(km) }
    }
}
