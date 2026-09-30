import Charts
import SwiftUI

/** States: one state's average today, its changes, where today sits in its range, its history and every fuel. */
struct StatesPage: View {
    let data: TrendsData
    let states: [String]
    @Binding var state: String
    @Binding var fuel: FuelType

    var body: some View {
        let series = data.series(state, fuel)
        HStack(spacing: 6) {
            ChoiceChips(options: states, selection: $state) { StateName.code($0) }
            Spacer(minLength: 6)
            fuelMenu
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        if let latest = series.last {
            headline(latest)
            let changes = StateFacts.comparisons(series)
            if !changes.isEmpty {
                RuledFigures(figures: changes.map { RuledFigure(label: $0.label, value: "\(TrendFormat.signed($0.change))¢", color: color(for: $0.change)) })
                    .padding(.top, 14)
            }
            if let position = StateFacts.rangePosition(series), let first = series.first {
                RangeScale(position: position, sentence: StateFacts.rangeSentence(position, since: first.date))
            }
            if !StateFacts.isCollecting(series), let first = series.first, let scale = StateFacts.bandScale(series) {
                TrendsSection(title: "Since \(TrendFormat.since(first.date))", note: "¢/L") {
                    Legend(items: [(.line(ServoMapColor.ink), "Average"), (.swatch(ServoMapColor.chartBand), scale.legend)])
                    BandChart(series: series, scale: scale)
                }
            }
            FuelLadder(rungs: StateFacts.fuelRungs(data.latestByFuel(state)), state: state, selected: fuel)
            SourceLine(states: [state])
        } else {
            TrendsPlaceholder(failed: data.failed)
        }
    }

    private var fuelMenu: some View {
        Menu {
            Picker("Fuel", selection: $fuel) {
                ForEach(FuelType.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(fuel.rawValue)
                Image(systemName: "chevron.down").imageScale(.small).fontWeight(.semibold)
            }
            .font(ServoMapFont.body(.footnote))
            .foregroundStyle(ServoMapColor.ink)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .overlay { Capsule().strokeBorder(ServoMapColor.line, lineWidth: 0.5) }
        }
        .sensoryFeedback(.selection, trigger: fuel)
    }

    private func headline(_ latest: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(StateName.full(state)) · \(fuel.rawValue) average today")
                .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TrendFormat.cents(latest.avg)).font(ServoMapFont.display(.largeTitle, weight: 600, size: 48)).monospacedDigit()
                    .contentTransition(.numericText(value: latest.avg))
                Text("¢/L").font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink3)
            }
            if let count = latest.stationCount {
                Text("\(count.formatted()) stations reporting").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }

    /** Rises in the dear colour, falls in the cheap one: the colour marks where the price went, not a verdict. */
    private func color(for change: Double) -> Color {
        change > 0.05 ? ServoMapColor.priceExpensive : change < -0.05 ? ServoMapColor.priceCheap : ServoMapColor.ink
    }
}

/** Today's average as a dot between the period's low and high average. */
private struct RangeScale: View {
    let position: RangePosition
    let sentence: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sentence).font(ServoMapFont.display(.title3, weight: 500, size: 19)).foregroundStyle(ServoMapColor.ink)
            Chart {
                RuleMark(xStart: .value("Low", 0), xEnd: .value("High", 1), y: .value("Row", 0))
                    .foregroundStyle(ServoMapColor.wash).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                RuleMark(xStart: .value("Low", 0), xEnd: .value("Quarter", 0.25), y: .value("Row", 0))
                    .foregroundStyle(ServoMapColor.priceCheapSoft).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                RuleMark(xStart: .value("Three quarters", 0.75), xEnd: .value("High", 1), y: .value("Row", 0))
                    .foregroundStyle(ServoMapColor.priceExpensiveSoft).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                PointMark(x: .value("Today", min(max(position.fraction, 0), 1)), y: .value("Row", 0))
                    .symbol { Circle().fill(ServoMapColor.ink).stroke(ServoMapColor.bg, lineWidth: 3).frame(width: 17, height: 17) }
            }
            .chartXScale(domain: 0...1)
            .chartYScale(domain: -1...1)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 18)
            HStack {
                Text("Low \(TrendFormat.cents(position.low.avg)) · \(TrendFormat.dayMonth(position.low.date))")
                Spacer()
                Text("High \(TrendFormat.cents(position.high.avg)) · \(TrendFormat.dayMonth(position.high.date))")
            }
            .font(ServoMapFont.body(.footnote)).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .accessibilityElement(children: .combine)
    }
}

/** The daily average over the spread of station prices, with each gap in the data shaded and named. */
private struct BandChart: View {
    let series: [Snapshot]
    let scale: BandScale

    var body: some View {
        let ticks = ChartScale.nice([scale.domain.lowerBound, scale.domain.upperBound], ticks: 4).ticks
            .filter { scale.domain.contains($0) }
        Chart {
            ForEach(Array(StateFacts.missingRanges(series).enumerated()), id: \.offset) { _, gap in
                RectangleMark(xStart: .value("From", TrendMath.day(gap.first).addingTimeInterval(-86_400)),
                              xEnd: .value("To", TrendMath.day(gap.last).addingTimeInterval(86_400)),
                              yStart: .value("Low", scale.domain.lowerBound), yEnd: .value("High", scale.domain.upperBound))
                    .foregroundStyle(ServoMapColor.wash)
                    .annotation(position: .overlay) {
                        VStack(spacing: 2) {
                            Text("No data")
                            Text(StateFacts.gapLabel(first: gap.first, last: gap.last).replacingOccurrences(of: "No data ", with: ""))
                        }
                        .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                    }
            }
            ForEach(Array(TrendMath.runs(series).enumerated()), id: \.offset) { index, run in
                ForEach(run, id: \.date) { s in
                    AreaMark(x: .value("Day", TrendMath.day(s.date)),
                             yStart: .value("Cheapest", clamp(s.min)), yEnd: .value("Dearest", clamp(s.max)),
                             series: .value("Run", "band\(index)"))
                        .foregroundStyle(ServoMapColor.chartBand)
                    LineMark(x: .value("Day", TrendMath.day(s.date)), y: .value("Average", s.avg), series: .value("Run", "avg\(index)"))
                        .foregroundStyle(ServoMapColor.ink)
                        .lineStyle(StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                }
            }
            if let last = series.last {
                PointMark(x: .value("Day", TrendMath.day(last.date)), y: .value("Average", last.avg))
                    .symbol { Circle().fill(ServoMapColor.ink).frame(width: 7, height: 7) }
            }
        }
        .chartYScale(domain: scale.domain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: ticks) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(ServoMapColor.lineSubtle)
                AxisValueLabel().font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .chartXAxis {
            AxisMarks(values: xLabels) { value in
                // The last day sits on the plot's right edge; anchoring it there keeps it from being dropped.
                AxisValueLabel(anchor: value.index == value.count - 1 ? .topTrailing : .top) {
                    if let date = value.as(Date.self) { Text(TrendFormat.dayMonth(TrendFormat.iso(date))) }
                }
                .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .chartPlotStyle { $0.clipped() }
        .frame(height: 178)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private func clamp(_ value: Double) -> Double { min(max(value, scale.domain.lowerBound), scale.domain.upperBound) }

    private var xDomain: ClosedRange<Date> {
        let first = series.first.map { TrendMath.day($0.date) } ?? .now
        let last = series.last.map { TrendMath.day($0.date) } ?? .now
        return first...max(last, first.addingTimeInterval(86_400))
    }

    /** The first of each month that has data, and the last day. */
    private var xLabels: [Date] {
        let firsts = series.filter { $0.date.hasSuffix("-01") }.map { TrendMath.day($0.date) }
        let last = series.last.map { TrendMath.day($0.date) }
        return firsts + (last.map { [$0] } ?? [])
    }

    private var summary: String {
        guard let first = series.first, let last = series.last else { return "No history" }
        return "Daily average from \(TrendFormat.cents(first.avg)) on \(TrendFormat.dayMonth(first.date)) to \(TrendFormat.cents(last.avg)) on \(TrendFormat.dayMonth(last.date))"
    }
}

/** Every fuel's state average today as dots on one scale, with the difference to U91 beside each. */
private struct FuelLadder: View {
    let rungs: [FuelRung]
    let state: String
    let selected: FuelType

    var body: some View {
        if !rungs.isEmpty {
            let scale = ChartScale.nice(rungs.map(\.average), ticks: 3, pad: 4)
            // Read on each redraw: the car setting may change while Trends is open.
            let defaults = UserDefaults.standard
            let tank = defaults.object(forKey: "tankLitres") == nil ? nil : defaults.integer(forKey: "tankLitres")
            TrendsSection(title: "Every fuel, today", note: "\(StateName.code(state)) average") {
                DotRows(rows: rungs, domain: scale.domain, ticks: scale.ticks, labelWidth: 56, rowHeight: 34) { rung in
                    Text(rung.fuel.rawValue).font(ServoMapFont.body(.subheadline)).foregroundStyle(ServoMapColor.ink)
                } value: { _ in
                    EmptyView()
                } marks: { rung in
                    RuleMark(xStart: .value("Scale", scale.domain.lowerBound), xEnd: .value("Average", rung.average), y: .value("Row", 0))
                        .foregroundStyle(ServoMapColor.line).lineStyle(StrokeStyle(lineWidth: 1))
                    PointMark(x: .value("Average", rung.average), y: .value("Row", 0))
                        .symbol { symbol(rung) }
                    // The figure is a second symbol offset beside the dot (annotations drift in one-row charts);
                    // near the right end it goes to the dot's left, as the artboard sets Diesel.
                    PointMark(x: .value("Average", rung.average), y: .value("Row", 0))
                        .symbol {
                            let left = nearEnd(rung, scale.domain)
                            label(rung).fixedSize()
                                .frame(width: 120, alignment: left ? .trailing : .leading)
                                .offset(x: left ? -70 : 70)
                        }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(rungs.map { "\($0.fuel.rawValue) \(TrendFormat.cents($0.average))" }.joined(separator: ", "))
                if let fact = StateFacts.fuelFact(rungs, selected: selected, tankLitres: tank) { ChartNote(fact) }
            }
        }
    }

    @ViewBuilder private func symbol(_ rung: FuelRung) -> some View {
        if rung.fuel == .u91 {
            Circle().fill(ServoMapColor.bg).stroke(ServoMapColor.ink, lineWidth: 2.5).frame(width: 13, height: 13)
        } else {
            Circle().fill(ServoMapColor.ink).frame(width: 11, height: 11)
        }
    }

    private func nearEnd(_ rung: FuelRung, _ domain: ClosedRange<Double>) -> Bool {
        (rung.average - domain.lowerBound) / (domain.upperBound - domain.lowerBound) > 0.7
    }

    private func label(_ rung: FuelRung) -> some View {
        let text = rung.fuel == .u91 || rung.difference == nil
            ? TrendFormat.cents(rung.average)
            : "\(TrendFormat.cents(rung.average)) · \(TrendFormat.signed(rung.difference ?? 0))"
        let color = rung.fuel == .u91 ? ServoMapColor.ink : (rung.difference ?? 0) < 0 ? ServoMapColor.priceCheap : ServoMapColor.ink2
        return Text(text).font(ServoMapFont.body(.caption, weight: rung.fuel == .u91 ? 600 : 400)).monospacedDigit().foregroundStyle(color)
    }
}
