import Charts
import SwiftUI

/** Timing: when prices move (collecting), how many stations reported in the last day, and WA's publishing time. */
struct TimingPage: View {
    let cities: [CityInsight]?
    let failed: Bool
    let fuel: FuelType
    /** The state chosen on States, whose changes the heatmap will count. */
    let state: String

    /** FuelWatch publishes the next day's prices at 2:30 pm WA time; they apply from 6 am the next day. */
    static let waPublishTime = "2:30 pm"

    var body: some View {
        TrendsSection(title: "When prices move", note: "\(StateName.code(state)) · \(fuel.rawValue)") {
            CollectingHeatmap()
            ChartNote("Each square will count the price rises and falls stations report in that hour.")
        }
        if let cities, !CityFacts.byReporting(cities).isEmpty {
            let rows = CityFacts.byReporting(cities)
            // In the shared city order (NSW first), so the credit reads as on the other pages.
            let states = cities.filter { $0.reportedWithin24hShare != nil }.map(\.state).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            TrendsSection(title: "Reported in the last day", note: "\(fuel.rawValue) stations") {
                ReportedChart(rows: rows)
                if let fact = CityFacts.reportingFact(states: states) { ChartNote(fact) }
            }
            if states.contains("wa") { publishRow }
            SourceLine(states: states)
        } else {
            TrendsPlaceholder(failed: failed)
        }
    }

    private var publishRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock").font(.system(size: 20, weight: .regular)).foregroundStyle(ServoMapColor.ink)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Tomorrow’s WA prices publish at \(Self.waPublishTime)").font(ServoMapFont.lead).foregroundStyle(ServoMapColor.ink)
                Text("\(DataSource.forState("wa")?.name ?? "FuelWatch") fixes each station’s price for the next day")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .accessibilityElement(children: .combine)
    }
}

/** The weekday by hour grid, blank until four weeks of changes exist, with a note saying when it opens. */
private struct CollectingHeatmap: View {
    private static let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        // A plain grid rather than a chart: until data exists it is a placeholder texture, not a plot.
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(Self.days.enumerated()), id: \.offset) { d, name in
                HStack(spacing: 6) {
                    Text(name).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3).frame(width: 28, alignment: .leading)
                    HStack(spacing: 2) {
                        ForEach(0..<24, id: \.self) { h in
                            RoundedRectangle(cornerRadius: ServoMapRadius.r1)
                                .fill(ServoMapColor.wash.opacity(texture(d, h)))
                                .frame(height: 14)
                        }
                    }
                }
            }
            HStack {
                ForEach([0, 6, 12, 18, 23], id: \.self) { h in
                    if h > 0 { Spacer(minLength: 0) }
                    Text(hour(h))
                }
            }
            .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            .padding(.leading, 34)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 2) {
                Text("Collecting since \(TrendFormat.dayMonth(CityFacts.historySince))").font(ServoMapFont.body(.footnote, weight: 600))
                Text("Opens with four weeks of changes, around \(CityFacts.opens(afterDays: CityFacts.heatmapDays))")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(ServoMapColor.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: ServoMapRadius.r3))
            .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r3).strokeBorder(ServoMapColor.line, lineWidth: 0.5))
            .padding(.top, 30)
            .padding(.leading, 34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekday by hour chart of price changes. Collecting since \(TrendFormat.dayMonth(CityFacts.historySince)); opens around \(CityFacts.opens(afterDays: CityFacts.heatmapDays)).")
    }

    /** An even, meaningless texture so the empty grid reads as a grid, not as data. */
    private func texture(_ day: Int, _ hour: Int) -> Double { 0.55 + 0.45 * Double((day * 7 + hour * 3) % 5) / 5 }

    private func hour(_ h: Int) -> String {
        switch h {
        case 0: "12 am"
        case 12: "12 pm"
        default: h < 12 ? "\(h) am" : "\(h - 12) pm"
        }
    }
}

/** Each city's share of stations with a price reported in the last 24 hours, as dots on a 0–100% scale. */
private struct ReportedChart: View {
    let rows: [CityInsight]

    var body: some View {
        DotRows(rows: rows, domain: 0...100, ticks: [0, 50, 100], labelWidth: 104, valueWidth: 48, rowHeight: 34,
                tickLabel: { $0 == 100 ? "100%" : "\(Int($0))" }) { city in
            Text(city.name).font(ServoMapFont.body(.subheadline)).foregroundStyle(ServoMapColor.ink)
        } value: { city in
            Text(percent(city)).font(ServoMapFont.body(.footnote)).monospacedDigit().foregroundStyle(ServoMapColor.ink)
        } marks: { city in
            let share = (city.reportedWithin24hShare ?? 0) * 100
            RuleMark(xStart: .value("None", 0), xEnd: .value("Share", share), y: .value("Row", 0))
                .foregroundStyle(ServoMapColor.line).lineStyle(StrokeStyle(lineWidth: 2))
            PointMark(x: .value("Share", share), y: .value("Row", 0))
                .symbol { Circle().fill(ServoMapColor.ink).frame(width: 11, height: 11) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rows.map { "\($0.name) \(percent($0))" }.joined(separator: ", "))
    }

    private func percent(_ city: CityInsight) -> String {
        "\(Int(((city.reportedWithin24hShare ?? 0) * 100).rounded()))%"
    }
}
