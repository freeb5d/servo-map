import Charts
import SwiftUI

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
