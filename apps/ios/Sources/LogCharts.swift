import Charts
import SwiftUI

/** Spend per month as thin bars; the current month is ink, earlier ones faint, with the average dashed. */
struct MonthlySpendChart: View {
    let months: [(month: Date, summary: MonthSummary)]

    var body: some View {
        let spent = months.map(\.summary.spent).filter { $0 > 0 }
        let average = spent.isEmpty ? nil : spent.reduce(0, +) / Double(spent.count)
        Chart {
            ForEach(Array(months.enumerated()), id: \.offset) { index, m in
                BarMark(x: .value("Month", m.month, unit: .month), y: .value("Spent", m.summary.spent), width: .fixed(12))
                    .foregroundStyle(index == months.count - 1 ? ServoMapColor.ink : ServoMapColor.ink3.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: ServoMapRadius.r1))
            }
            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(ServoMapColor.ink3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("average \(average.formatted(.currency(code: "AUD").precision(.fractionLength(0))))")
                            .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true) }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(ServoMapColor.line)
                AxisValueLabel(format: .currency(code: "AUD").precision(.fractionLength(0)))
            }
        }
        .frame(height: 150)
    }
}

/**
 * Each fill-up's price as a dot, with a stem to the local average at the time: green when you
 * paid under it, red when over. The length of the stem is the saving (or the overspend).
 */
struct PricePaidChart: View {
    let fills: [FillUp]

    var body: some View {
        Chart(fills) { f in
            if let avg = f.areaAverage {
                RuleMark(x: .value("Date", f.date, unit: .day), yStart: .value("Paid", f.centsPerLitre), yEnd: .value("Average", avg))
                    .foregroundStyle((avg > f.centsPerLitre ? ServoMapColor.priceCheap : ServoMapColor.priceExpensive).opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Date", f.date, unit: .day), y: .value("Average", avg))
                    .symbol { Rectangle().fill(ServoMapColor.ink3).frame(width: 9, height: 1.5) }
            }
            PointMark(x: .value("Date", f.date, unit: .day), y: .value("Paid", f.centsPerLitre))
                .symbol { Circle().fill(ServoMapColor.ink).frame(width: 7, height: 7) }
        }
        .chartYScale(domain: domain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])).foregroundStyle(ServoMapColor.line)
                AxisValueLabel()
            }
        }
        .frame(height: 160)
        .accessibilityLabel("Price paid at each fill-up against the local average at the time")
    }

    /** Tight to the prices and averages, on whole tens, so the stems are long enough to read. */
    private var domain: ClosedRange<Double> {
        let values = fills.flatMap { [$0.centsPerLitre] + ($0.areaAverage.map { [$0] } ?? []) }
        let lo = ((values.min() ?? 0) / 10).rounded(.down) * 10
        let hi = ((values.max() ?? 10) / 10).rounded(.up) * 10
        return lo...max(hi, lo + 10)
    }
}

/** Key for PricePaidChart, drawn with the same marks. */
struct PricePaidLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) { Circle().fill(ServoMapColor.ink).frame(width: 7, height: 7); Text("You paid") }
            HStack(spacing: 5) { Rectangle().fill(ServoMapColor.ink3).frame(width: 9, height: 1.5); Text("Local average") }
        }
        .font(ServoMapFont.label)
        .foregroundStyle(ServoMapColor.ink3)
        .accessibilityHidden(true)
    }
}
