import SwiftUI

/** Body shapes the car catalogue maps every model to (decision 0004); drawn by ServoMap, not photos. */
enum BodyType: String, CaseIterable, Codable, Sendable, Identifiable {
    case hatch, sedan, wagon, suv, ute, van
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hatch: "Hatch"
        case .sedan: "Sedan"
        case .wagon: "Wagon"
        case .suv: "SUV"
        case .ute: "Ute"
        case .van: "Van"
        }
    }
}

/**
 * A car in side view: body, glasshouse and wheels, in one flat style for every body type. The
 * body takes the car's colour; windows and wheels come from the page palette.
 */
struct CarSilhouette: View {
    let body_: BodyType
    var paint: Color = ServoMapColor.ink2

    init(_ body: BodyType, paint: Color = ServoMapColor.ink2) {
        body_ = body
        self.paint = paint
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Profile(points: shape.body).fill(paint)
                Profile(points: shape.glass).fill(ServoMapColor.surface.opacity(0.85))
                ForEach(shape.wheels, id: \.self) { x in
                    Circle().fill(ServoMapColor.ink).frame(width: h * 0.34, height: h * 0.34)
                        .overlay(Circle().fill(ServoMapColor.line).padding(h * 0.1))
                        .position(x: w * x, y: h * 0.8)
                }
            }
        }
        .aspectRatio(2.6, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var shape: (body: [CGPoint], glass: [CGPoint], wheels: [CGFloat]) {
        switch body_ {
        case .hatch:
            return ([p(0.04, 0.8), p(0.04, 0.58), p(0.1, 0.5), p(0.3, 0.44), p(0.42, 0.22), p(0.72, 0.2), p(0.9, 0.44), p(0.97, 0.52), p(0.97, 0.8)],
                    [p(0.36, 0.44), p(0.45, 0.27), p(0.62, 0.26), p(0.62, 0.44)], [0.22, 0.8])
        case .sedan:
            return ([p(0.02, 0.8), p(0.02, 0.58), p(0.08, 0.5), p(0.28, 0.46), p(0.4, 0.26), p(0.64, 0.25), p(0.76, 0.44), p(0.96, 0.48), p(0.98, 0.8)],
                    [p(0.34, 0.45), p(0.43, 0.3), p(0.62, 0.3), p(0.7, 0.45)], [0.2, 0.8])
        case .wagon:
            return ([p(0.02, 0.8), p(0.02, 0.58), p(0.08, 0.5), p(0.28, 0.45), p(0.4, 0.25), p(0.92, 0.24), p(0.97, 0.46), p(0.98, 0.8)],
                    [p(0.34, 0.44), p(0.43, 0.29), p(0.88, 0.29), p(0.9, 0.44)], [0.2, 0.82])
        case .suv:
            return ([p(0.03, 0.8), p(0.03, 0.5), p(0.1, 0.42), p(0.28, 0.4), p(0.38, 0.16), p(0.92, 0.15), p(0.97, 0.4), p(0.98, 0.8)],
                    [p(0.34, 0.39), p(0.42, 0.21), p(0.88, 0.21), p(0.9, 0.39)], [0.21, 0.81])
        case .ute:
            return ([p(0.02, 0.8), p(0.02, 0.5), p(0.1, 0.42), p(0.26, 0.4), p(0.34, 0.16), p(0.56, 0.15), p(0.58, 0.44), p(0.98, 0.44), p(0.98, 0.8)],
                    [p(0.31, 0.39), p(0.38, 0.21), p(0.53, 0.21), p(0.53, 0.39)], [0.2, 0.8])
        case .van:
            return ([p(0.03, 0.8), p(0.03, 0.45), p(0.12, 0.2), p(0.2, 0.1), p(0.96, 0.1), p(0.98, 0.3), p(0.98, 0.8)],
                    [p(0.13, 0.4), p(0.21, 0.17), p(0.36, 0.17), p(0.36, 0.4)], [0.19, 0.83])
        }
    }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /** A closed outline through unit points, corners softened. */
    private struct Profile: Shape {
        let points: [CGPoint]
        func path(in rect: CGRect) -> Path {
            let pts = points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
            var path = Path()
            guard pts.count > 2 else { return path }
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let next = pts[(i + 1) % pts.count]
                path.addArc(tangent1End: pts[i], tangent2End: next, radius: rect.height * 0.08)
            }
            path.closeSubpath()
            return path
        }
    }
}
