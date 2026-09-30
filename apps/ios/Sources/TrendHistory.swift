import Charts
import SwiftUI

/**
 * The state history, after evilcharts' composed and brush charts: the daily average as a soft area,
 * the cheapest price in the state that day as a dotted line under it, a second fuel dashed for
 * comparison, and missing days hatched. It scrolls through the whole history; `HistoryOverview`
 * below it is the brush that shows and moves the window.
 */
struct HistoryChart: View {
    let series: [Snapshot]
    let fuel: FuelType
    let compare: [Snapshot]
    let compareFuel: FuelType
    /** Days in view at once. */
    let windowDays: Int
    @Binding var start: Date
    @State private var picked: Date?

    var body: some View {
        Chart {
            ForEach(Array(TrendMath.runs(series).enumerated()), id: \.offset) { index, run in
                ForEach(run, id: \.date) { s in
                    AreaMark(x: .value("Day", TrendMath.day(s.date)),
                             yStart: .value("Floor", domain.lowerBound), yEnd: .value("Average", s.avg),
                             series: .value("Run", "a\(index)"))
                        .foregroundStyle(LinearGradient(colors: [ServoMapColor.ink.opacity(0.14), ServoMapColor.ink.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg), series: .value("Run", "m\(index)"))
                        .foregroundStyle(by: .value("Series", "\(fuel.rawValue) average"))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Cheapest", s.min), series: .value("Run", "l\(index)"))
                        .foregroundStyle(by: .value("Series", "Cheapest in NSW"))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.5, 3]))
                        .interpolationMethod(.monotone)
                }
            }
            ForEach(Array(TrendMath.runs(compare).enumerated()), id: \.offset) { index, run in
                ForEach(run, id: \.date) { s in
                    LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg), series: .value("Run", "c\(index)"))
                        .foregroundStyle(by: .value("Series", "\(compareFuel.rawValue) average"))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                        .interpolationMethod(.monotone)
                }
            }
            if let point = nearest {
                RuleMark(x: .value("Day", TrendMath.day(point.date)))
                    .foregroundStyle(ServoMapColor.ink3.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        ReadOut(snapshot: point)
                    }
                PointMark(x: .value("Day", TrendMath.day(point.date)), y: .value("Average", point.avg))
                    .symbol { Circle().fill(ServoMapColor.surface).stroke(ServoMapColor.ink, lineWidth: 2).frame(width: 11, height: 11) }
            }
        }
        .chartForegroundStyleScale([
            "\(fuel.rawValue) average": ServoMapColor.ink,
            "Cheapest in NSW": ServoMapColor.priceCheap,
            "\(compareFuel.rawValue) average": ServoMapColor.ink3,
        ])
        .chartLegend(position: .top, alignment: .leading, spacing: 12)
        .chartYScale(domain: domain)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: Double(windowDays) * 86_400)
        .chartScrollPosition(x: $start)
        .chartXSelection(value: $picked)
        .chartXAxis {
            AxisMarks(values: .stride(by: windowDays <= 45 ? .weekOfYear : .month)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [1, 3])).foregroundStyle(ServoMapColor.line)
                AxisValueLabel(format: windowDays <= 45 ? .dateTime.day().month(.abbreviated) : .dateTime.month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(ServoMapColor.line)
                AxisValueLabel()
            }
        }
        .chartOverlay { proxy in HatchedGaps(gaps: TrendMath.gaps(series), proxy: proxy) }
        .frame(height: 240)
        .padding(.top, 30)
        .accessibilityLabel(summary)
    }

    /** Y range of the days in view, so scrolling keeps the line using the chart's height. */
    private var domain: ClosedRange<Double> {
        let end = start.addingTimeInterval(Double(windowDays) * 86_400)
        let inView = (series + compare).filter { (start...end).contains(TrendMath.day($0.date)) }
        let values = (inView.isEmpty ? series : inView).flatMap { [$0.avg, $0.min] }
        let lo = ((values.min() ?? 0) / 5).rounded(.down) * 5
        let hi = ((values.max() ?? 5) / 5).rounded(.up) * 5
        return lo...max(hi, lo + 5)
    }

    private var nearest: Snapshot? {
        guard let picked else { return nil }
        return series.min { abs(TrendMath.day($0.date).timeIntervalSince(picked)) < abs(TrendMath.day($1.date).timeIntervalSince(picked)) }
    }

    private var summary: String {
        guard let latest = series.last else { return "No history" }
        return "\(fuel.rawValue) state average \(latest.avg.formatted(.number.precision(.fractionLength(1)))) cents on \(latest.date)"
    }
}

/** The read-out above a picked day: average, cheapest and date. */
private struct ReadOut: View {
    let snapshot: Snapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(TrendMath.day(snapshot.date), format: .dateTime.weekday(.abbreviated).day().month())
                .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            Text("\(snapshot.avg.formatted(.number.precision(.fractionLength(1)))) avg")
                .font(ServoMapFont.body(.caption, weight: 600)).monospacedDigit()
            Text("\(snapshot.min.formatted(.number.precision(.fractionLength(1)))) cheapest")
                .font(ServoMapFont.label).monospacedDigit().foregroundStyle(ServoMapColor.priceCheap)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(ServoMapColor.surface, in: RoundedRectangle(cornerRadius: ServoMapRadius.r2))
        .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r2).strokeBorder(ServoMapColor.line, lineWidth: 0.5))
    }
}

/** Diagonal hatching over days with no data, so a gap reads as missing rather than flat. */
private struct HatchedGaps: View {
    let gaps: [(Date, Date)]
    let proxy: ChartProxy

    var body: some View {
        GeometryReader { geo in
            let plot = proxy.plotFrame.map { geo[$0] } ?? .zero
            Canvas { context, _ in
                for (from, to) in gaps {
                    guard let x0 = proxy.position(forX: from), let x1 = proxy.position(forX: to), x1 > x0 else { continue }
                    let rect = CGRect(x: plot.minX + x0, y: plot.minY, width: x1 - x0, height: plot.height)
                    context.fill(Path(rect), with: .color(ServoMapColor.wash.opacity(0.5)))
                    var stripes = Path()
                    var x = rect.minX - rect.height
                    while x < rect.maxX {
                        stripes.move(to: CGPoint(x: x, y: rect.maxY))
                        stripes.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
                        x += 6
                    }
                    context.clip(to: Path(rect))
                    context.stroke(stripes, with: .color(ServoMapColor.ink3.opacity(0.25)), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/**
 * The brush: the whole history as a thin area with the window in view outlined. Dragging it
 * moves the chart above.
 */
struct HistoryOverview: View {
    let series: [Snapshot]
    let windowDays: Int
    @Binding var start: Date

    var body: some View {
        let end = start.addingTimeInterval(Double(windowDays) * 86_400)
        Chart {
            ForEach(series, id: \.date) { s in
                AreaMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg))
                    .foregroundStyle(ServoMapColor.ink3.opacity(0.25))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg))
                    .foregroundStyle(ServoMapColor.ink3)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
            }
            RectangleMark(xStart: .value("From", start), xEnd: .value("To", end))
                .foregroundStyle(ServoMapColor.ink.opacity(0.08))
            RuleMark(x: .value("From", start)).foregroundStyle(ServoMapColor.ink).lineStyle(StrokeStyle(lineWidth: 2))
            RuleMark(x: .value("To", end)).foregroundStyle(ServoMapColor.ink).lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let plot = proxy.plotFrame.map { geo[$0] } ?? .zero
                        guard let centre: Date = proxy.value(atX: value.location.x - plot.minX),
                              let first = series.first.map({ TrendMath.day($0.date) }),
                              let last = series.last.map({ TrendMath.day($0.date) }) else { return }
                        let half = Double(windowDays) * 86_400 / 2
                        let latest = max(first, last.addingTimeInterval(-2 * half))
                        start = min(max(centre.addingTimeInterval(-half), first), latest)
                    })
            }
        }
        .frame(height: 40)
        .accessibilityLabel("History overview. Drag to move the window.")
    }
}

/**
 * Where today sits in the period, after evilcharts' semi-circle radial chart: a half gauge from the
 * period's low to its high, shaded cheap to dear, with a needle at today's average.
 */
struct CycleGauge: View {
    let low: Double
    let high: Double
    let today: Double

    var body: some View {
        let t = high > low ? min(max((today - low) / (high - low), 0), 1) : 0.5
        VStack(spacing: 0) {
            ZStack {
                Arc(from: 0, to: 1)
                    .stroke(ServoMapColor.wash, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                Arc(from: 0, to: 1)
                    .stroke(AngularGradient(colors: [ServoMapColor.priceCheap, ServoMapColor.priceMid, ServoMapColor.priceExpensive],
                                            center: .bottom, startAngle: .degrees(180), endAngle: .degrees(360)),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .opacity(0.35)
                Arc(from: max(t - 0.004, 0), to: min(t + 0.004, 1))
                    .stroke(ServoMapColor.ink, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                VStack(spacing: 2) {
                    Spacer()
                    Text(today, format: .number.precision(.fractionLength(1)))
                        .font(ServoMapFont.display(.title2)).monospacedDigit()
                    Text("\(Int((t * 100).rounded()))% of the way to the high")
                        .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                }
            }
            .frame(height: 110)
            HStack {
                Text("Low \(low.formatted(.number.precision(.fractionLength(1))))")
                Spacer()
                Text("High \(high.formatted(.number.precision(.fractionLength(1))))")
            }
            .font(ServoMapFont.label).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today \(today.formatted(.number.precision(.fractionLength(1)))), between the low of \(low.formatted(.number.precision(.fractionLength(1)))) and the high of \(high.formatted(.number.precision(.fractionLength(1))))")
    }

    /** A slice of the upper half circle, 0 at the left end and 1 at the right. */
    private struct Arc: Shape {
        let from: Double
        let to: Double
        func path(in rect: CGRect) -> Path {
            let r = min(rect.width / 2, rect.height) - 11
            let centre = CGPoint(x: rect.midX, y: rect.maxY - 4)
            var p = Path()
            p.addArc(center: centre, radius: r, startAngle: .degrees(180 + 180 * from), endAngle: .degrees(180 + 180 * to), clockwise: false)
            return p
        }
    }
}

/**
 * Average by weekday as slim bars on a narrow scale, after evilcharts' monospace bar block: the
 * cheapest day in the cheap colour with its value, the others quiet.
 */
struct WeekdayBars: View {
    let days: [(String, Double?)]

    var body: some View {
        let known = days.compactMap { d in d.1.map { (d.0, $0) } }
        let lo = known.map(\.1).min() ?? 0
        let hi = known.map(\.1).max() ?? 1
        Chart(known, id: \.0) { name, avg in
            BarMark(x: .value("Day", name), yStart: .value("Floor", lo - (hi - lo) * 0.6 - 0.2), yEnd: .value("Average", avg),
                    width: .ratio(0.42))
                .foregroundStyle(avg == lo ? ServoMapColor.priceCheap : ServoMapColor.ink3.opacity(avg == hi ? 0.55 : 0.28))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .annotation(position: .top, spacing: 3) {
                    Text(avg, format: .number.precision(.fractionLength(1)))
                        .font(.system(size: 10, weight: avg == lo ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(avg == lo ? ServoMapColor.priceCheap : ServoMapColor.ink3)
                }
        }
        .chartXScale(domain: days.map(\.0))
        .chartYScale(domain: (lo - (hi - lo) * 0.6 - 0.2)...(hi + (hi - lo) * 0.15 + 0.1))
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks { _ in AxisValueLabel().font(ServoMapFont.body(.caption, weight: 500)) } }
        .frame(height: 150)
    }
}
