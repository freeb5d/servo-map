import SwiftUI

/**
 * Trends in the Health manner: the state average with its history at the top, then highlight cards
 * that each state one finding in a sentence and show the data behind it.
 */
struct TrendsScreen: View {
    @Environment(Store.self) private var store
    @State private var rangeDays: Int? = 30

    var body: some View {
        NavigationStack {
            List {
                hero
                Section { weekdayCard } header: { GroupTitle("Highlights") }
                Section { spreadCard }
                if !brandRows.isEmpty { Section { brandCard } }
                fuels
                suburbs
                SavingsSection(series: shown)
            }
            .paperList()
            .navigationTitle("Trends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    @Bindable var store = store
                    Picker("Fuel", selection: $store.fuel) {
                        ForEach(FuelType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var shown: [Snapshot] { TrendMath.window(store.trend, days: rangeDays) }
    /** E10 is what most U91 drivers could switch to; everyone else compares against U91. */
    private var compareFuel: FuelType { store.fuel == .u91 ? .e10 : .u91 }

    // MARK: Hero

    private var hero: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                CardHeader(title: "NSW average \(store.fuel.rawValue)", symbol: "chart.line.uptrend.xyaxis", note: "Updated daily")
                if let latest = store.trend.last {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        PriceText(cents: latest.avg, font: ServoMapFont.priceXl)
                        if let week = TrendMath.change(store.trend, days: 7) {
                            Text("\(week >= 0 ? "+" : "")\(fmt(week)) this week")
                                .font(ServoMapFont.small).monospacedDigit().foregroundStyle(changeColor(week))
                        }
                    }
                }
                Text(TrendMath.verdict(shown) ?? "Not enough history yet.").font(ServoMapFont.display(.body, weight: 500))
                Picker("Range", selection: $rangeDays) {
                    Text("30 days").tag(Int?.some(30))
                    Text("90 days").tag(Int?.some(90))
                    Text("All").tag(Int?.none)
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
                HistoryChart(series: shown, fuel: store.fuel,
                             compare: TrendMath.window(store.trend(for: compareFuel), days: rangeDays), compareFuel: compareFuel)
            }
            .padding(.vertical, 6)
            .paperRow()
        }
    }

    // MARK: Highlights

    private var weekdayCard: some View {
        let days = TrendMath.weekdays(shown).compactMap { d in d.1.map { (d.0, $0) } }
        let cheapest = days.min { $0.1 < $1.1 }
        let dearest = days.max { $0.1 < $1.1 }
        return VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Cheapest day", symbol: "calendar", note: rangeNote)
            if let cheapest, let dearest, dearest.1 > cheapest.1 {
                Text("\(fullDay(cheapest.0)) is usually the cheapest day, \(fmt(dearest.1 - cheapest.1))¢ under \(fullDay(dearest.0)).")
                    .font(ServoMapFont.display(.body, weight: 500))
            }
            WeekdayChart(days: TrendMath.weekdays(shown))
        }
        .padding(.vertical, 6)
        .paperRow()
    }

    private var spreadCard: some View {
        // The stations in the Nearby list, so the numbers here match what the map shows.
        let prices = store.ranked.compactMap { $0.price(store.fuel)?.price }
        return VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Spread nearby", symbol: "arrow.left.and.right", note: "\(prices.count) stations")
            if let lo = prices.min(), let hi = prices.max() {
                Text("Near \(store.placeName), \(store.fuel.rawValue) ranges \(fmt(hi - lo))¢ today, from \(fmt(lo)) to \(fmt(hi)).")
                    .font(ServoMapFont.display(.body, weight: 500))
            }
            SpreadStrip(prices: prices, range: store.range, average: store.localAverage)
        }
        .padding(.vertical, 6)
        .paperRow()
    }

    private var brandCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Brands nearby", symbol: "storefront", note: "Today")
            if let best = brandRows.first, let avg = store.localAverage, avg > best.1 {
                Text("\(best.0.name) stations average \(fmt(avg - best.1))¢ under the local average.")
                    .font(ServoMapFont.display(.body, weight: 500))
            }
            BrandChart(rows: Array(brandRows.prefix(8)), average: store.localAverage)
        }
        .padding(.vertical, 6)
        .paperRow()
    }

    // MARK: Lists

    private var fuels: some View {
        Section {
            ForEach(FuelType.allCases) { fuel in
                let series = store.trend(for: fuel)
                if let latest = series.last {
                    Button { store.fuel = fuel } label: {
                        HStack(spacing: 12) {
                            Text(fuel.rawValue).fontWeight(fuel == store.fuel ? .semibold : .regular).frame(width: 52, alignment: .leading)
                            Sparkline(series: TrendMath.window(series, days: 30))
                            Spacer()
                            if let week = TrendMath.change(series, days: 7) {
                                Text("\(week >= 0 ? "+" : "")\(fmt(week))")
                                    .font(ServoMapFont.small).monospacedDigit().foregroundStyle(changeColor(week))
                            }
                            PriceText(cents: latest.avg, font: ServoMapFont.lead)
                        }
                        .foregroundStyle(ServoMapColor.ink)
                    }
                    .accessibilityAddTraits(fuel == store.fuel ? .isSelected : [])
                }
            }
            .paperRow()
        } header: {
            GroupTitle("All fuels")
        } footer: {
            Text("State averages, the last 30 days. Tap a fuel to show its trends.")
        }
    }

    private var suburbs: some View {
        Section {
            ForEach(suburbRows.prefix(5), id: \.0) { suburb, low, count in
                LabeledContent {
                    PriceText(cents: low, font: ServoMapFont.lead)
                } label: {
                    Text(suburb)
                    Text("\(count) station\(count == 1 ? "" : "s")")
                }
            }
            .paperRow()
        } header: {
            GroupTitle("Cheapest suburbs today")
        }
    }

    // MARK: Data

    private var rangeNote: String { rangeDays.map { "Last \($0) days" } ?? "All history" }

    private func fullDay(_ short: String) -> String {
        ["Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday"][short] ?? short
    }

    private func changeColor(_ change: Double) -> Color {
        change > 0.05 ? ServoMapColor.priceExpensive : change < -0.05 ? ServoMapColor.priceCheap : ServoMapColor.ink3
    }

    private var brandRows: [(BrandFamily, Double, Int)] {
        let rows = store.stations.compactMap { s in s.price(store.fuel).map { (s.family, $0.price) } }
        return Dictionary(grouping: rows, by: { $0.0 })
            .map { family, r in (family, r.map(\.1).reduce(0, +) / Double(r.count), r.count) }
            .sorted { $0.1 < $1.1 }
    }

    private var suburbRows: [(String, Double, Int)] {
        let rows = store.stations.compactMap { s in s.price(store.fuel).map { (s.suburb, $0.price) } }
        return Dictionary(grouping: rows, by: { $0.0 })
            .compactMap { suburb, r in r.map(\.1).min().map { (suburb, $0, r.count) } }
            .sorted { $0.1 < $1.1 }
    }
}

private func fmt(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }

/** What choosing well adds up to over a year, from the reader's own tank and habits. */
private struct SavingsSection: View {
    @Environment(Store.self) private var store
    let series: [Snapshot]
    @AppStorage("tankLitres") private var litres = 50
    @AppStorage("fillsPerMonth") private var fills = 3

    var body: some View {
        Section {
            Group {
                Stepper("Tank fill  \(litres) L", value: $litres, in: 20...120, step: 5)
                Stepper("Fills a month  \(fills)", value: $fills, in: 1...12)
                if let saving = cheapestVsAverage {
                    LabeledContent("Cheapest nearby, not average") { yearly(saving) }
                }
                if let saving = bestDay {
                    LabeledContent("\(saving.0) instead of \(saving.1)") { yearly(saving.2) }
                }
            }
            .paperRow()
        } header: {
            GroupTitle("Over a year")
        } footer: {
            Text("Kept on this iPhone.")
        }
    }

    private func yearly(_ centsPerLitre: Double) -> some View {
        Text((centsPerLitre * Double(litres * fills * 12) / 100).formatted(.currency(code: "AUD").precision(.fractionLength(0))))
            .font(ServoMapFont.display(.body)).monospacedDigit()
            .foregroundStyle(ServoMapColor.ink)
    }

    private var cheapestVsAverage: Double? {
        guard let avg = store.localAverage, let low = store.ranked.first?.price(store.fuel)?.price else { return nil }
        return avg - low
    }

    private var bestDay: (String, String, Double)? {
        let days = TrendMath.weekdays(series).compactMap { d in d.1.map { (d.0, $0) } }
        guard let lo = days.min(by: { $0.1 < $1.1 }), let hi = days.max(by: { $0.1 < $1.1 }) else { return nil }
        return (lo.0, hi.0, hi.1 - lo.1)
    }
}
