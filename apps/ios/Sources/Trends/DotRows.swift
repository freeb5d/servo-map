import Charts
import SwiftUI

/**
 * Rows of marks on one shared horizontal scale: a label column, a one-row chart per row, and a value
 * column, with the scale's ticks under the last row. Each row is its own chart so labels sit outside
 * the plot at a fixed width and rows can be tapped; the shared domain keeps every row on one scale.
 */
struct DotRows<Row: Identifiable, Label: View, Value: View, Marks: ChartContent>: View {
    let rows: [Row]
    let domain: ClosedRange<Double>
    let ticks: [Double]
    var labelWidth: CGFloat = 48
    var valueWidth: CGFloat = 0
    var rowHeight: CGFloat = 36
    var tickLabel: (Double) -> String = { $0.formatted(.number.precision(.fractionLength(0)).grouping(.never)) }
    var onTap: ((Row) -> Void)? = nil
    @ViewBuilder let label: (Row) -> Label
    @ViewBuilder let value: (Row) -> Value
    @ChartContentBuilder let marks: (Row) -> Marks

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: 0) {
                    label(row).frame(width: labelWidth, alignment: .leading)
                    Chart { marks(row) }
                        .chartXScale(domain: domain)
                        .chartYScale(domain: -1...1)
                        .chartYAxis(.hidden)
                        .chartXAxis {
                            AxisMarks(values: ticks) { _ in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(ServoMapColor.lineSubtle)
                            }
                        }
                        .frame(height: rowHeight)
                    if valueWidth > 0 {
                        value(row).frame(width: valueWidth, alignment: .trailing)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onTap?(row) }
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: labelWidth, height: 1)
                TickLabels(domain: domain, ticks: ticks, text: tickLabel)
                if valueWidth > 0 { Color.clear.frame(width: valueWidth, height: 1) }
            }
        }
    }
}

/** Tick values centred under their gridlines; edge labels may run into the label and value columns. */
struct TickLabels: View {
    let domain: ClosedRange<Double>
    let ticks: [Double]
    let text: (Double) -> String

    var body: some View {
        GeometryReader { geo in
            ForEach(ticks, id: \.self) { tick in
                let span = domain.upperBound - domain.lowerBound
                let x = span > 0 ? (tick - domain.lowerBound) / span * geo.size.width : 0
                Text(text(tick))
                    .font(ServoMapFont.label).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
                    .fixedSize()
                    .position(x: x, y: 9)
            }
        }
        .frame(height: 20)
        .accessibilityHidden(true)
    }
}
