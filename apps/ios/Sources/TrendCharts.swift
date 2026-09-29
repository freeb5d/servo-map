import Charts
import SwiftUI

/**
 * Daily average with gaps left open (after evilcharts.com: soft gradient area, a dashed comparison
 * series, faint horizontal grid only, bordered end dots). Tap or drag to read any day.
 */
struct HistoryChart: View {
    let series: [Snapshot]
    let fuel: FuelType
    /** A second fuel drawn dashed for comparison; nil hides it. */
    let compare: [Snapshot]
    let compareFuel: FuelType?
    @State private var picked: Date?

    var body: some View {
        Chart {
            ForEach(Array(TrendMath.gaps(series).enumerated()), id: \.offset) { _, gap in
                RectangleMark(xStart: .value("From", gap.0), xEnd: .value("To", gap.1))
                    .foregroundStyle(ServoMapColor.wash.opacity(0.6))
                    .annotation(position: .overlay) {
                        Text("No data").font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                    }
            }
            if let compareFuel {
                ForEach(Array(TrendMath.runs(compare).enumerated()), id: \.offset) { index, run in
                    ForEach(run, id: \.date) { s in
                        LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg), series: .value("Run", "c\(index)"))
                            .foregroundStyle(by: .value("Fuel", compareFuel.rawValue))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            .interpolationMethod(.monotone)
                    }
                }
            }
            // One series per run of consecutive days, so line and area break at gaps instead of bridging them.
            ForEach(Array(TrendMath.runs(series).enumerated()), id: \.offset) { index, run in
                ForEach(run, id: \.date) { s in
                    AreaMark(x: .value("Day", TrendMath.day(s.date)), yStart: .value("Floor", floor), yEnd: .value("Average", s.avg), series: .value("Run", "a\(index)"))
                        .foregroundStyle(LinearGradient(colors: [ServoMapColor.ink.opacity(0.16), ServoMapColor.ink.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg), series: .value("Run", "m\(index)"))
                        .foregroundStyle(by: .value("Fuel", fuel.rawValue))
                        .lineStyle(StrokeStyle(lineWidth: 1.8))
                        .interpolationMethod(.monotone)
                }
                if let end = run.last {
                    PointMark(x: .value("Day", TrendMath.day(end.date)), y: .value("Average", end.avg))
                        .symbol { Circle().fill(ServoMapColor.surface).stroke(ServoMapColor.ink, lineWidth: 1.5).frame(width: 7, height: 7) }
                }
            }
            if let point = nearest {
                RuleMark(x: .value("Day", TrendMath.day(point.date)))
                    .foregroundStyle(ServoMapColor.ink3.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        VStack(spacing: 0) {
                            Text(point.avg, format: .number.precision(.fractionLength(1)))
                                .font(ServoMapFont.body(.subheadline, weight: 600)).monospacedDigit()
                            Text(TrendMath.day(point.date), format: .dateTime.day().month())
                                .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                        }
                    }
                PointMark(x: .value("Day", TrendMath.day(point.date)), y: .value("Average", point.avg))
                    .symbol { Circle().fill(ServoMapColor.ink).stroke(ServoMapColor.surface, lineWidth: 2).frame(width: 10, height: 10) }
            }
        }
        .chartForegroundStyleScale([fuel.rawValue: ServoMapColor.ink, (compareFuel ?? fuel).rawValue: ServoMapColor.ink3])
        .chartLegend(position: .top, alignment: .trailing)
        .chartXSelection(value: $picked)
        .chartYScale(domain: floor...ceiling)
        .chartXAxis {
            // A short window has at most one month boundary, so it is labelled by week instead.
            if spanDays <= 45 {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) }
            } else {
                AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true) }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(ServoMapColor.line)
                AxisValueLabel()
            }
        }
        .frame(height: 230)
        .padding(.top, 28)
    }

    private var spanDays: Double {
        guard let first = series.first, let last = series.last else { return 0 }
        return TrendMath.day(last.date).timeIntervalSince(TrendMath.day(first.date)) / 86_400
    }

    private var values: [Double] { (series + (compareFuel == nil ? [] : compare)).map(\.avg) }
    private var floor: Double { ((values.min() ?? 0) / 10).rounded(.down) * 10 }
    private var ceiling: Double { ((values.max() ?? 1) / 10).rounded(.up) * 10 }

    private var nearest: Snapshot? {
        guard let picked else { return nil }
        return series.min { abs(TrendMath.day($0.date).timeIntervalSince(picked)) < abs(TrendMath.day($1.date).timeIntervalSince(picked)) }
    }
}

/** A word-sized line of the last weeks, for the all-fuels list. */
struct Sparkline: View {
    let series: [Snapshot]
    var body: some View {
        Chart(Array(TrendMath.runs(series).enumerated()), id: \.offset) { index, run in
            ForEach(run, id: \.date) { s in
                LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Avg", s.avg), series: .value("Run", index))
                    .foregroundStyle(ServoMapColor.ink2)
                    .lineStyle(StrokeStyle(lineWidth: 1.2))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(width: 64, height: 22)
        .accessibilityHidden(true)
    }
}

/** Weekday averages as dots on a shared scale: no bars, so no truncated-axis caveat is needed. */
struct WeekdayChart: View {
    let days: [(String, Double?)]
    var body: some View {
        let known = days.compactMap { d in d.1.map { (d.0, $0) } }
        let lowest = known.map(\.1).min()
        Chart(known, id: \.0) { name, avg in
            PointMark(x: .value("Day", name), y: .value("Average", avg))
                .foregroundStyle(avg == lowest ? ServoMapColor.priceCheap : ServoMapColor.ink2)
                .symbolSize(avg == lowest ? 90 : 45)
                .annotation(position: .top) {
                    Text(avg, format: .number.precision(.fractionLength(1)))
                        .font(ServoMapFont.body(.caption2, weight: avg == lowest ? 600 : 400)).monospacedDigit()
                        .foregroundStyle(avg == lowest ? ServoMapColor.ink : ServoMapColor.ink3)
                }
        }
        .chartXScale(domain: days.map(\.0))
        .chartXAxis { AxisMarks { _ in AxisValueLabel() } }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis(.hidden)
        .frame(height: 130)
    }
}

/** Brand averages as a dot plot against the local average. */
struct BrandChart: View {
    let rows: [(BrandFamily, Double, Int)]
    let average: Double?

    var body: some View {
        Chart {
            if let average {
                RuleMark(x: .value("Local average", average))
                    .foregroundStyle(ServoMapColor.ink3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("average").font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                    }
            }
            ForEach(rows, id: \.0.id) { family, avg, count in
                PointMark(x: .value("Average", avg), y: .value("Brand", family.seal == family.name.uppercased() ? family.name : "\(family.seal)  \(family.name)"))
                    .foregroundStyle(ServoMapColor.ink)
                    .symbolSize(Double(min(count, 30)) * 6 + 30)
                    .annotation(position: .trailing) {
                        Text(avg, format: .number.precision(.fractionLength(1)))
                            .font(ServoMapFont.body(.caption)).monospacedDigit().foregroundStyle(ServoMapColor.ink2)
                    }
            }
        }
        .chartXScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel() } }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(ServoMapColor.line)
                AxisValueLabel()
            }
        }
        .frame(height: CGFloat(rows.count) * 30 + 40)
    }
}

/**
 * Every station's price nearby as a dot in its tier colour, stacked in 1¢ columns like a histogram,
 * with the local average dashed. Shows where most prices sit and how far the dear ones stray.
 */
struct SpreadStrip: View {
    let prices: [Double]
    let range: PriceRange
    let average: Double?

    var body: some View {
        Chart {
            ForEach(stacked, id: \.offset) { dot in
                PointMark(x: .value("Price", dot.column + 0.5), y: .value("Stations", Double(dot.level) + 0.5))
                    .foregroundStyle(range.tier(dot.price).color)
                    .symbolSize(30)
            }
            if let average {
                RuleMark(x: .value("Local average", average))
                    .foregroundStyle(ServoMapColor.ink3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, spacing: 2) {
                        Text("average \(average.formatted(.number.precision(.fractionLength(1))))")
                            .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                    }
            }
        }
        .chartYScale(domain: 0...Double(max(tallest, 4)))
        .chartYAxis(.hidden)
        .chartXScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel() } }
        .frame(height: CGFloat(max(tallest, 4)) * 9 + 30)
        .padding(.top, 16)
        .accessibilityLabel("Prices at \(prices.count) stations nearby")
    }

    /** Each price placed in its whole-cent column, one level above the last price in that column. */
    private var stacked: [(offset: Int, price: Double, column: Double, level: Int)] {
        var levels: [Double: Int] = [:]
        return prices.sorted().enumerated().map { index, price in
            let column = price.rounded(.down)
            let level = levels[column, default: 0]
            levels[column] = level + 1
            return (index, price, column, level)
        }
    }

    private var tallest: Int {
        Dictionary(grouping: prices, by: { $0.rounded(.down) }).values.map(\.count).max() ?? 0
    }
}
