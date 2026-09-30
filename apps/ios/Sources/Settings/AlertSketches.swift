import SwiftUI

/** A price that steps down with a small arrow: "a saved station drops". */
struct PriceDropSketch: View {
    var body: some View {
        Canvas { context, _ in
            var step = Path()
            step.move(to: CGPoint(x: 2, y: 10))
            step.addLine(to: CGPoint(x: 20, y: 10))
            step.addLine(to: CGPoint(x: 20, y: 24))
            step.addLine(to: CGPoint(x: 44, y: 24))
            context.stroke(step, with: .color(ServoMapColor.ink), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            var arrow = Path()
            arrow.move(to: CGPoint(x: 24, y: 12))
            arrow.addLine(to: CGPoint(x: 24, y: 21))
            arrow.move(to: CGPoint(x: 21, y: 18.5))
            arrow.addLine(to: CGPoint(x: 24, y: 21.5))
            arrow.addLine(to: CGPoint(x: 27, y: 18.5))
            context.stroke(arrow, with: .color(ServoMapColor.priceCheap), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            context.fill(Path(ellipseIn: CGRect(x: 41.6, y: 21.6, width: 4.8, height: 4.8)), with: .color(ServoMapColor.priceCheap))
        }
        .frame(width: 46, height: 34)
        .accessibilityHidden(true)
    }
}

/** A price cycle ending in the cheap band at the bottom of its range: "prices are low near home". */
struct CycleLowSketch: View {
    var body: some View {
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 0, y: 23, width: 46, height: 9)), with: .color(ServoMapColor.priceCheapSoft))
            var cycle = Path()
            cycle.move(to: CGPoint(x: 2, y: 12))
            cycle.addCurve(to: CGPoint(x: 18, y: 16), control1: CGPoint(x: 8, y: 6), control2: CGPoint(x: 12, y: 22))
            cycle.addCurve(to: CGPoint(x: 34, y: 14), control1: CGPoint(x: 24, y: 10), control2: CGPoint(x: 28, y: 4))
            cycle.addCurve(to: CGPoint(x: 44, y: 25), control1: CGPoint(x: 40, y: 24), control2: CGPoint(x: 42, y: 26))
            context.stroke(cycle, with: .color(ServoMapColor.ink3), lineWidth: 1.4)
            context.fill(Path(ellipseIn: CGRect(x: 41.6, y: 22.6, width: 4.8, height: 4.8)), with: .color(ServoMapColor.priceCheap))
        }
        .frame(width: 46, height: 34)
        .accessibilityHidden(true)
    }
}

/** Quiet hours on a 24-hour day, which may run past midnight (22 to 7). */
enum QuietHours {
    /** The quiet parts of the day as fractions of it, left to right. */
    static func segments(start: Int, end: Int) -> [ClosedRange<Double>] {
        let s = Double(start) / 24, e = Double(end) / 24
        if start == end { return [] }
        return start > end ? [0...e, s...1] : [s...e]
    }

    /** "10 pm – 7 am" in the reader's clock style. */
    static func label(start: Int, end: Int) -> String {
        "\(hour(start)) – \(hour(end))"
    }

    static func hour(_ h: Int) -> String {
        Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)?
            .formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))) ?? "\(h):00"
    }
}

/** The day as a bar with its quiet hours in ink, labelled at midnight, the end and the start. */
struct QuietHoursStrip: View {
    let start: Int
    let end: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                let r = ServoMapRadius.r3
                RoundedRectangle(cornerRadius: r).fill(ServoMapColor.wash).frame(height: 12).offset(y: 4)
                ForEach(QuietHours.segments(start: start, end: end), id: \.lowerBound) { part in
                    UnevenRoundedRectangle(topLeadingRadius: part.lowerBound == 0 ? r : 0, bottomLeadingRadius: part.lowerBound == 0 ? r : 0,
                                           bottomTrailingRadius: part.upperBound == 1 ? r : 0, topTrailingRadius: part.upperBound == 1 ? r : 0)
                        .fill(ServoMapColor.ink.opacity(0.8))
                        .frame(width: w * (part.upperBound - part.lowerBound), height: 12)
                        .offset(x: w * part.lowerBound, y: 4)
                }
                tick(QuietHours.hour(0), at: 0, width: w, align: .leading)
                tick(QuietHours.hour(end), at: Double(end) / 24, width: w, align: .center)
                tick(QuietHours.hour(start), at: Double(start) / 24, width: w, align: .trailing)
            }
        }
        .frame(height: 32)
        .animation(ServoMapMotion.standard, value: start)
        .animation(ServoMapMotion.standard, value: end)
        .accessibilityHidden(true)
    }

    private func tick(_ text: String, at fraction: Double, width: CGFloat, align: HorizontalAlignment) -> some View {
        Text(text).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3).monospacedDigit()
            .fixedSize()
            .alignmentGuide(.leading) { d in
                align == .leading ? 0 : align == .center ? d.width / 2 - width * fraction : d.width - width * fraction
            }
            .offset(y: 18)
    }
}
