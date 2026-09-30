import Charts
import SwiftUI

/** Overview: today's fact, every state's average in a ruled row, average against cheapest, and each state since the start. */
struct OverviewPage: View {
    let data: TrendsData
    @Binding var fuel: FuelType
    let openState: (String) -> Void

    var body: some View {
        let byState = data.byState(fuel)
        let latest = StateFacts.latest(byState)
        ChoiceChips(options: FuelType.allCases, selection: $fuel) { $0.rawValue }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        if latest.isEmpty {
            TrendsPlaceholder(failed: data.failed)
        } else {
            if let fact = StateFacts.factOfTheDay(fuel: fuel, latest) {
                FactLine(caption: latest.map(\.snapshot.date).max().map(dayCaption), text: fact)
            }
            RuledFigures(figures: figures(latest)).padding(.top, 16)
            TrendsSection(title: "Average and cheapest", note: "¢/L today") {
                Legend(items: [(.ring(ServoMapColor.priceCheap), "Cheapest station"), (.dot(ServoMapColor.ink), "State average")])
                DumbbellChart(rows: latest)
                if let gap = StateFacts.widestGap(latest) { ChartNote(gap) }
            }
            SinceStart(byState: byState, order: latest.map(\.state), openState: openState)
            SourceLine(states: latest.map(\.state), note: "Averages are the mean of every station reporting that fuel that day.")
        }
    }

    /** "Today, 30 September", or just the date when the latest data is from another day. */
    private func dayCaption(_ date: String) -> String {
        date == TrendFormat.today() ? "Today, \(TrendFormat.dayLongMonth(date))" : TrendFormat.dayLongMonth(date)
    }

    /** The cheapest state's figure in the cheap colour and the dearest in the dear one. */
    private func figures(_ latest: [StateLatest]) -> [RuledFigure] {
        let averages = latest.map(\.snapshot.avg)
        let lo = averages.min(), hi = averages.max()
        return latest.map { row in
            let avg = row.snapshot.avg
            let color = lo == hi ? ServoMapColor.ink : avg == lo ? ServoMapColor.priceCheap : avg == hi ? ServoMapColor.priceExpensive : ServoMapColor.ink
            return RuledFigure(label: StateName.code(row.state), value: TrendFormat.cents(avg), color: color)
        }
    }
}

extension StateLatest: Identifiable {
    var id: String { state }
}

/** Each state's cheapest station and average on one scale: the gap between them is the line. */
private struct DumbbellChart: View {
    let rows: [StateLatest]

    var body: some View {
        let scale = ChartScale.nice(rows.flatMap { [$0.snapshot.min, $0.snapshot.avg] }, ticks: 3, pad: 2)
        DotRows(rows: rows, domain: scale.domain, ticks: scale.ticks, labelWidth: 44, valueWidth: 104) { row in
            Text(StateName.code(row.state)).font(ServoMapFont.body(.subheadline)).foregroundStyle(ServoMapColor.ink)
        } value: { row in
            Text("\(TrendFormat.cents(row.snapshot.min)) · \(TrendFormat.cents(row.snapshot.avg))")
                .font(ServoMapFont.body(.footnote)).monospacedDigit().foregroundStyle(ServoMapColor.ink)
        } marks: { row in
            RuleMark(xStart: .value("Cheapest", row.snapshot.min), xEnd: .value("Average", row.snapshot.avg), y: .value("Row", 0))
                .foregroundStyle(ServoMapColor.line)
                .lineStyle(StrokeStyle(lineWidth: 2))
            PointMark(x: .value("Cheapest", row.snapshot.min), y: .value("Row", 0))
                .symbol { Circle().fill(ServoMapColor.bg).stroke(ServoMapColor.priceCheap, lineWidth: 2).frame(width: 10, height: 10) }
            PointMark(x: .value("Average", row.snapshot.avg), y: .value("Row", 0))
                .symbol { Circle().fill(ServoMapColor.ink).frame(width: 11, height: 11) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rows.map { "\(StateName.full($0.state)): cheapest \(TrendFormat.cents($0.snapshot.min)), average \(TrendFormat.cents($0.snapshot.avg))" }.joined(separator: ". "))
    }
}

/** "Since June": one small chart per state on a shared scale, with the data gaps shaded. */
private struct SinceStart: View {
    let byState: [String: [Snapshot]]
    let order: [String]
    let openState: (String) -> Void

    var body: some View {
        let shown = order.filter { byState[$0] != nil }
        let all = shown.flatMap { byState[$0] ?? [] }
        let yScale = StateFacts.sharedScale(all.map(\.avg))
        let days = all.map { TrendMath.day($0.date) }
        let first = all.min { $0.date < $1.date }
        if let start = days.min(), let end = days.max(), let first {
            let gaps = Array(Set(shown.flatMap { StateFacts.missingRanges(byState[$0] ?? []).map { "\($0.first)|\($0.last)" } })).sorted()
            TrendsSection(title: "Since \(TrendFormat.since(first.date))", note: "daily average, \(Int(yScale.lowerBound))–\(Int(yScale.upperBound))¢") {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 18) {
                    ForEach(shown, id: \.self) { state in
                        Button { openState(state) } label: {
                            SmallMultiple(state: state, series: byState[state] ?? [], x: start...end, y: yScale)
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(gaps, id: \.self) { gap in
                    let parts = gap.split(separator: "|").map(String.init)
                    HStack(spacing: 8) {
                        Rectangle().fill(ServoMapColor.wash).frame(width: 14, height: 10)
                        Text(StateFacts.gapLabel(first: parts[0], last: parts[1]))
                    }
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                }
            }
        }
    }
}

/** One state's daily average on the shared scale, or a "collecting" marker while it has only a few days. */
private struct SmallMultiple: View {
    let state: String
    let series: [Snapshot]
    let x: ClosedRange<Date>
    let y: ClosedRange<Double>

    var body: some View {
        let collecting = StateFacts.isCollecting(series)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(StateName.code(state)).font(ServoMapFont.body(.subheadline, weight: 600)).foregroundStyle(ServoMapColor.ink)
                Spacer()
                Text(collecting ? TrendFormat.days(series.count) : "\(TrendFormat.signed(change))¢")
                    .font(ServoMapFont.small).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
            }
            chart(collecting: collecting).frame(height: 61)
            Group {
                if collecting, let first = series.first {
                    Text("Collecting since \(TrendFormat.dayMonth(first.date))")
                } else if let first = series.first, let last = series.last {
                    Text("\(TrendFormat.cents(first.avg)) → \(TrendFormat.cents(last.avg))").monospacedDigit()
                }
            }
            .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows this state")
    }

    private var change: Double { (series.last?.avg ?? 0) - (series.first?.avg ?? 0) }

    private func chart(collecting: Bool) -> some View {
        Chart {
            ForEach(Array(TrendMath.gaps(series).enumerated()), id: \.offset) { _, gap in
                RectangleMark(xStart: .value("From", gap.0), xEnd: .value("To", gap.1), yStart: .value("Low", y.lowerBound), yEnd: .value("High", y.upperBound))
                    .foregroundStyle(ServoMapColor.wash)
            }
            RuleMark(y: .value("Floor", y.lowerBound)).foregroundStyle(ServoMapColor.line).lineStyle(StrokeStyle(lineWidth: 1))
            if collecting, let last = series.last {
                RuleMark(xStart: .value("Start", x.lowerBound), xEnd: .value("Today", TrendMath.day(last.date)), y: .value("Average", last.avg))
                    .foregroundStyle(ServoMapColor.line).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            } else {
                ForEach(Array(TrendMath.runs(series).enumerated()), id: \.offset) { index, run in
                    ForEach(run, id: \.date) { s in
                        LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg), series: .value("Run", index))
                            .foregroundStyle(ServoMapColor.ink).lineStyle(StrokeStyle(lineWidth: 1.4))
                    }
                }
            }
            if let last = series.last {
                PointMark(x: .value("Day", TrendMath.day(last.date)), y: .value("Average", last.avg))
                    .symbol { Circle().fill(ServoMapColor.ink).frame(width: 4.5, height: 4.5) }
            }
        }
        .chartXScale(domain: x)
        .chartYScale(domain: y)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}
