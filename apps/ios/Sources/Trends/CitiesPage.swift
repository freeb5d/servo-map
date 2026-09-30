import Charts
import SwiftUI

/** Cities: each city's average and range today, one city's every price, and city history once it is collected. */
struct CitiesPage: View {
    let cities: [CityInsight]?
    let failed: Bool
    let fuel: FuelType
    @State private var picked: String?

    var body: some View {
        if let cities, !CityFacts.ranked(cities).isEmpty {
            let ranked = CityFacts.ranked(cities)
            let shown = cities.first { $0.id == picked && $0.histogram != nil } ?? CityFacts.defaultCity(cities)
            if let fact = CityFacts.cheapestFact(ranked) {
                FactLine(caption: "\(fuel.rawValue) today · \(CityFacts.radiusCaption(cities))", text: fact)
            }
            TrendsSection(title: nil) {
                Legend(items: [(.dot(ServoMapColor.ink), "Average"), (.bar(ServoMapColor.line), "Cheapest to dearest")])
                RangePlot(ranked: ranked, picked: shown?.id) { id in
                    withAnimation(ServoMapMotion.snappy) { picked = id }
                }
            }
            .padding(.top, -4)
            if let shown, let histogram = shown.histogram {
                Distribution(city: shown, histogram: histogram)
            }
            CollectingHistory()
            SourceLine(states: unique(cities.filter { $0.average != nil }.map(\.state)), note: "City averages and ranges use prices reported in the last 7 days.")
        } else {
            TrendsPlaceholder(failed: failed)
        }
    }

    private func unique(_ states: [String]) -> [String] {
        states.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
}

/** Cities cheapest first: a dot at the average on a line from the cheapest to the dearest station. */
private struct RangePlot: View {
    let ranked: [CityInsight]
    let picked: String?
    let pick: (String) -> Void

    var body: some View {
        let scale = ChartScale.nice(ranked.flatMap { [$0.min, $0.max].compactMap { $0 } }, ticks: 4)
        DotRows(rows: ranked, domain: scale.domain, ticks: scale.ticks, labelWidth: 104, valueWidth: 52, rowHeight: 40,
                onTap: { pick($0.id) }) { city in
            VStack(alignment: .leading, spacing: 0) {
                Text(city.name).font(ServoMapFont.body(.subheadline, weight: city.id == picked ? 600 : 400))
                    .foregroundStyle(ServoMapColor.ink).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(StateName.code(city.state)) · \(city.count)").font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            }
        } value: { city in
            if let avg = city.average {
                Text(TrendFormat.cents(avg)).font(ServoMapFont.display(.footnote, weight: 600)).monospacedDigit()
                    .foregroundStyle(color(city))
            }
        } marks: { city in
            if let lo = city.min, let hi = city.max {
                RuleMark(xStart: .value("Cheapest", lo), xEnd: .value("Dearest", hi), y: .value("Row", 0))
                    .foregroundStyle(ServoMapColor.line).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            if let avg = city.average {
                PointMark(x: .value("Average", avg), y: .value("Row", 0))
                    .symbol { Circle().fill(color(city)).frame(width: 11, height: 11) }
            }
        }
        .sensoryFeedback(.selection, trigger: picked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ranked.compactMap { c in
            c.average.map { "\(c.name) \(TrendFormat.cents($0)), \(c.count) stations" }
        }.joined(separator: ". "))
        .accessibilityAdjustableAction { direction in
            // VoiceOver swipes up and down through the cities to change the distribution below.
            guard let index = ranked.firstIndex(where: { $0.id == picked }) else { return }
            let next = direction == .increment ? min(index + 1, ranked.count - 1) : max(index - 1, 0)
            pick(ranked[next].id)
        }
    }

    /** The cheapest city in the cheap colour and the dearest in the dear one. */
    private func color(_ city: CityInsight) -> Color {
        guard ranked.count > 1 else { return ServoMapColor.ink }
        return city.id == ranked.first?.id ? ServoMapColor.priceCheap : city.id == ranked.last?.id ? ServoMapColor.priceExpensive : ServoMapColor.ink
    }
}

/** How many of one city's stations charge each price, with the median marked. */
private struct Distribution: View {
    let city: CityInsight
    let histogram: CityHistogram

    var body: some View {
        let bins = histogram.bins
        let low = bins.first?.lower ?? 0, high = bins.last?.upper ?? 1
        TrendsSection(title: "\(city.name), every price", note: "\(city.stationCount) stations, any age") {
            Chart {
                ForEach(bins, id: \.lower) { bin in
                    RectangleMark(xStart: .value("From", bin.lower + histogram.width * 0.05),
                                  xEnd: .value("To", bin.upper - histogram.width * 0.05),
                                  yStart: .value("None", 0), yEnd: .value("Stations", bin.count))
                        .foregroundStyle(ServoMapColor.ink.opacity(0.9))
                }
                if let median = city.median {
                    RuleMark(x: .value("Median", median))
                        .foregroundStyle(ServoMapColor.chartMedian)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .annotation(position: .top, alignment: .leading, spacing: 2,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            Text("median \(TrendFormat.cents(median))").font(ServoMapFont.label).foregroundStyle(ServoMapColor.chartMedian)
                        }
                }
                RuleMark(y: .value("None", 0)).foregroundStyle(ServoMapColor.line).lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartXScale(domain: low...high)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [low, high] + (city.median.map { [$0.rounded()] } ?? [])) { value in
                    // The ends sit on the plot's edges; anchoring them inward keeps them from being dropped.
                    let v = value.as(Double.self)
                    AxisValueLabel(anchor: v == low ? .topLeading : v == high ? .topTrailing : .top) {
                        if let v = value.as(Double.self) { Text(v == high ? "\(Int(v))¢" : "\(Int(v))") }
                    }
                    .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                }
            }
            .frame(height: 150)
            .padding(.top, 14)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(city.stationCount) \(city.name) stations from \(Int(low)) to \(Int(high)) cents, median \(city.median.map(TrendFormat.cents) ?? "unknown")")
            if let fact = CityFacts.histogramFact(histogram) { ChartNote(fact) }
        }
    }
}

/** City history is still being collected (decision 0006): a placeholder that says when it opens. */
private struct CollectingHistory: View {
    var body: some View {
        TrendsSection(title: "Cities over time") {
            ZStack(alignment: .bottomLeading) {
                ServoMapColor.surface
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 60))
                    p.addCurve(to: CGPoint(x: 110, y: 52), control1: CGPoint(x: 40, y: 58), control2: CGPoint(x: 70, y: 50))
                    p.addCurve(to: CGPoint(x: 210, y: 42), control1: CGPoint(x: 150, y: 54), control2: CGPoint(x: 170, y: 40))
                    p.addCurve(to: CGPoint(x: 320, y: 36), control1: CGPoint(x: 250, y: 44), control2: CGPoint(x: 290, y: 34))
                }
                .stroke(ServoMapColor.lineSubtle, style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                .frame(height: 96, alignment: .topLeading)
                .accessibilityHidden(true)
                Text("Collecting since \(TrendFormat.dayMonth(CityFacts.historySince)). A \(CityFacts.cityHistoryDays)-day view opens on \(CityFacts.opens(afterDays: CityFacts.cityHistoryDays)).")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink2)
                    .padding(.bottom, 10)
            }
            .frame(height: 96)
            .overlay(alignment: .topTrailing) {
                Circle().fill(ServoMapColor.ink).frame(width: 8, height: 8).padding(.top, 32).padding(.trailing, 2).accessibilityHidden(true)
            }
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) { Hairline() }
        }
    }
}
