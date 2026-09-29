import Charts
import SwiftUI

/**
 * Filters as a system form, filled with the data behind each choice: the price distribution,
 * how many stations each option removes, and every brand's station count and average today.
 */
struct FilterSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                PriceSection(filters: $store.filters)
                distance
                freshness
                BrandSection(filters: $store.filters)
                alsoSells
            }
            .paperList()
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { store.filters = Filters() }.disabled(store.filters == Filters())
                }
                // The count sits on the confirm button in the bar, as iOS forms do, rather than a
                // full-width bar floating over the list.
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.ranked.isEmpty ? "No matches" : "Show \(store.ranked.count)") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .disabled(store.ranked.isEmpty)
                        .accessibilityLabel(store.ranked.isEmpty ? "No stations match" : "Show \(store.ranked.count) stations")
                }
            }
        }
    }

    private var distance: some View {
        @Bindable var store = store
        return Section {
            Picker("Within", selection: $store.filters.radiusKm) {
                Text("Any").tag(Int?.none)
                ForEach([2, 5, 10], id: \.self) { Text("\($0) km").tag(Int?.some($0)) }
            }
            .pickerStyle(.segmented)
            .paperRow()
        } header: {
            Text("Distance")
        } footer: {
            let from = store.located ? "your location" : store.placeName
            Text(store.filters.radiusKm == nil ? "Measured from \(from)." : "Measured from \(from). Hides \(removedCount { $0.radiusKm = nil }) stations further out.")
        }
    }

    private var freshness: some View {
        @Bindable var store = store
        return Section {
            Picker("Updated", selection: $store.filters.freshHours) {
                Text("Any").tag(Int?.none)
                ForEach([1, 6, 24], id: \.self) { Text("\($0) h").tag(Int?.some($0)) }
            }
            .pickerStyle(.segmented)
            .paperRow()
        } header: {
            Text("Price updated within")
        } footer: {
            Text(store.filters.freshHours == nil ? "Prices older than a day never rank." : "Hides \(removedCount { $0.freshHours = nil }) stations. Prices older than a day never rank.")
        }
    }

    private var alsoSells: some View {
        Section {
            HStack(spacing: 8) {
                ForEach(FuelType.allCases.filter { $0 != store.fuel }) { fuel in
                    Toggle(fuel.rawValue, isOn: Binding(
                        get: { store.filters.alsoSells.contains(fuel) },
                        set: { on in if on { store.filters.alsoSells.insert(fuel) } else { store.filters.alsoSells.remove(fuel) } }))
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                }
            }
            .paperRow()
        } header: {
            Text("Also sells")
        } footer: {
            Text("Useful when you run two cars on different fuels.")
        }
    }

    /** Stations that would come back if this one setting were cleared. */
    private func removedCount(_ clear: (inout Filters) -> Void) -> Int {
        var without = store.filters
        clear(&without)
        return store.matching(without).count - store.ranked.count
    }
}

private struct PriceSection: View {
    @Environment(Store.self) private var store
    @Binding var filters: Filters

    var body: some View {
        let prices = store.stations.compactMap { $0.price(store.fuel)?.price }
        let bounds = (prices.min() ?? 150).rounded(.down)...(prices.max() ?? 300).rounded(.up)
        let ceiling = filters.maxPrice ?? bounds.upperBound

        Section {
            histogramChart(histogram(prices, bins: 28), bounds: bounds, ceiling: ceiling).paperRow()

            Slider(value: Binding(get: { ceiling }, set: { filters.maxPrice = $0 >= bounds.upperBound ? nil : $0.rounded() }),
                   in: bounds, step: 1)
                .paperRow()
            LabeledContent("Up to") {
                Text(filters.maxPrice == nil ? "Any price" : "\(ceiling.formatted(.number.precision(.fractionLength(1)))) ¢/L")
            }
            .paperRow()
        } header: {
            Text("Price, \(store.fuel.rawValue)")
        } footer: {
            if let avg = store.localAverage {
                Text("Local average \(avg.formatted(.number.precision(.fractionLength(1)))) ¢/L.")
            }
        }
    }

    private func histogramChart(_ bins: [Bin], bounds: ClosedRange<Double>, ceiling: Double) -> some View {
        let top: Double = Double(max(1, bins.map(\.count).max() ?? 1))
        // Empty bins are left out rather than drawn as slivers.
        return Chart(bins.filter { $0.count > 0 }, id: \.from) { (bin: Bin) in
            RectangleMark(xStart: .value("From", bin.barStart), xEnd: .value("To", bin.barEnd),
                    yStart: .value("None", 0.0), yEnd: .value("Stations", Double(bin.count)))
                .cornerRadius(1)
                .foregroundStyle(barStyle(bin, ceiling: ceiling))
        }
        .chartXScale(domain: bounds)
        .chartYScale(domain: 0.0...top)
        .chartYAxis(.hidden)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 90)
        .accessibilityLabel("How many stations charge each price")
    }

    private struct Bin {
        let from: Double
        let mid: Double
        let width: Double
        let count: Int
        var barStart: Double { mid - width * 0.22 }
        var barEnd: Double { mid + width * 0.22 }
    }

    /** Bars at or under the ceiling are ink; the rest fade back to the hairline colour. */
    private func barStyle(_ bin: Bin, ceiling: Double) -> AnyShapeStyle {
        AnyShapeStyle(bin.mid <= ceiling ? ServoMapColor.ink.opacity(0.55) : ServoMapColor.line)
    }

    private func histogram(_ prices: [Double], bins: Int) -> [Bin] {
        guard let lo = prices.min(), let hi = prices.max(), hi > lo else { return [] }
        let width = (hi - lo) / Double(bins)
        var counts = Array(repeating: 0, count: bins)
        for p in prices { counts[min(bins - 1, Int((p - lo) / width))] += 1 }
        return counts.enumerated().map { i, c in Bin(from: lo + Double(i) * width, mid: lo + (Double(i) + 0.5) * width, width: width, count: c) }
    }
}

private struct BrandSection: View {
    @Environment(Store.self) private var store
    @Binding var filters: Filters

    private static let groups: [(BrandFamily.Group, String)] = [
        (.major, "Majors"), (.value, "Value chains"), (.members, "Members only"), (.independent, "Independent"),
    ]

    var body: some View {
        let stats = brandStats
        Section {
            Picker("Brands", selection: $filters.hideBrands) {
                Text("Only these").tag(false)
                Text("Hide these").tag(true)
            }
            .pickerStyle(.segmented)
            .paperRow()
        } header: {
            Text("Brands")
        } footer: {
            Text(filters.brands.isEmpty ? "No brands chosen, so every brand shows." : "\(filters.brands.count) chosen.")
        }

        ForEach(Self.groups, id: \.0) { group, title in
            let families = BrandFamily.all.filter { $0.group == group }
            Section(title) {
                ForEach(families) { family in
                    brandRow(family, stats[family.id]).paperRow()
                }
            }
        }
    }

    private func brandRow(_ family: BrandFamily, _ stat: (count: Int, avg: Double)?) -> some View {
        Button {
            if filters.brands.contains(family.id) { filters.brands.remove(family.id) } else { filters.brands.insert(family.id) }
        } label: {
            HStack(spacing: 12) {
                BrandSeal(family: family)
                VStack(alignment: .leading, spacing: 1) {
                    Text(family.name).foregroundStyle(ServoMapColor.ink)
                    Text(stat.map { "\($0.count) nearby" } ?? "None nearby")
                        .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                }
                Spacer()
                if let stat { PriceText(cents: stat.avg, font: ServoMapFont.lead) }
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .opacity(filters.brands.contains(family.id) ? 1 : 0)
                    .foregroundStyle(ServoMapColor.accent)
            }
        }
        .disabled(stat == nil)
    }

    private var brandStats: [String: (count: Int, avg: Double)] {
        let rows = store.stations.compactMap { s in s.price(store.fuel).map { (s.family.id, $0.price) } }
        return Dictionary(grouping: rows, by: \.0).mapValues { ($0.count, $0.map(\.1).reduce(0, +) / Double($0.count)) }
    }
}
