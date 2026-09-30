import SwiftUI

/**
 * Saved stations, cheapest first, each with how its price moved since you last looked.
 * When nothing is saved yet it offers the cheapest stations nearby to save in one tap.
 */
struct SavedScreen: View {
    @Environment(Store.self) private var store
    @State private var far: [Station] = []
    /** Price per station when this screen was last shown; the baseline for the change column. */
    @AppStorage("savedLastSeen") private var lastSeenRaw = "{}"
    @State private var baseline: [String: Double] = [:]

    var body: some View {
        NavigationStack {
            List {
                if saved.isEmpty {
                    emptySections
                } else {
                    summary
                    Section {
                        ForEach(saved) { station in
                            NavigationLink(value: station) { SavedRow(station: station, fuel: store.fuel, before: baseline[station.id]) }
                                .swipeActions {
                                    Button("Remove", systemImage: "bookmark.slash", role: .destructive) { store.toggleSaved(station) }
                                }
                        }
                        .paperRow()
                    } footer: {
                        Text("Changes are since you last opened Saved. Saved stations stay on this iPhone.")
                    }
                    PriceAlertsSection()
                }
            }
            .paperList()
            .navigationTitle("Saved")
            .task(id: store.savedIDs) { await loadFar() }
            .onAppear { baseline = decode(lastSeenRaw) }
            .onDisappear { remember() }
            .navigationDestination(for: Station.self) { StationDetail(station: $0) }
        }
    }

    // MARK: Sections

    private var summary: some View {
        Section {
            if let best = saved.first, let p = best.price(store.fuel) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(saved.count) saved").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        PriceText(cents: p.price, font: ServoMapFont.display(.title))
                        BrandSeal(family: best.family, size: 22)
                        Text(best.suburb).foregroundStyle(ServoMapColor.ink2)
                    }
                    Text("is the cheapest of your stations for \(store.fuel.rawValue) right now.")
                        .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder private var emptySections: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "bookmark").font(.system(size: 34, weight: .light)).foregroundStyle(ServoMapColor.ink3)
                Text("No saved stations yet").font(ServoMapFont.display(.title3, weight: 500))
                Text("Save the stations you use, and this page shows their price and how it has moved since you last looked.")
                    .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .listRowBackground(Color.clear)
        }
        if !store.ranked.isEmpty {
            Section("Cheapest near \(store.placeName)") {
                ForEach(store.ranked.prefix(3)) { station in
                    HStack {
                        StationRow(station: station, fuel: store.fuel, range: store.range)
                        Button { store.toggleSaved(station) } label: {
                            Image(systemName: "bookmark").actionFont()
                        }
                        .buttonStyle(.glass)
                        .accessibilityLabel("Save \(station.name)")
                    }
                }
                .paperRow()
            }
        }
    }

    // MARK: Data

    /** Saved stations with a price for the current fuel, cheapest first, including ones outside the loaded area. */
    private var saved: [Station] {
        let nearby = store.stations.filter(store.isSaved)
        let ids = Set(nearby.map(\.id))
        return (nearby + far.filter { !ids.contains($0.id) && store.isSaved($0) })
            .filter { $0.price(store.fuel) != nil }
            .sorted { ($0.price(store.fuel)?.price ?? .infinity) < ($1.price(store.fuel)?.price ?? .infinity) }
    }

    private func loadFar() async {
        let loaded = Set(store.stations.map(\.id))
        var out: [Station] = []
        for id in store.savedIDs where !loaded.contains(id) {
            if let s = try? await API().station(id: id) { out.append(s) }
        }
        far = out
    }

    private func remember() {
        var seen = decode(lastSeenRaw)
        for s in saved { if let p = s.price(store.fuel) { seen["\(s.id)|\(store.fuel.rawValue)"] = p.price } }
        if let data = try? JSONEncoder().encode(seen), let text = String(data: data, encoding: .utf8) { lastSeenRaw = text }
    }

    /** Baseline keyed by station id for the current fuel. */
    private func decode(_ raw: String) -> [String: Double] {
        let all = (try? JSONDecoder().decode([String: Double].self, from: Data(raw.utf8))) ?? [:]
        let suffix = "|\(store.fuel.rawValue)"
        return Dictionary(uniqueKeysWithValues: all.compactMap { key, value in
            key.hasSuffix(suffix) ? (String(key.dropLast(suffix.count)), value) : nil
        })
    }
}

private struct SavedRow: View {
    let station: Station
    let fuel: FuelType
    let before: Double?

    var body: some View {
        HStack(spacing: 12) {
            BrandSeal(family: station.family)
            VStack(alignment: .leading, spacing: 2) {
                Text(station.name).font(ServoMapFont.lead).lineLimit(1)
                Text(change).font(ServoMapFont.small).foregroundStyle(changeColor).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let p = station.price(fuel) {
                VStack(alignment: .trailing, spacing: 2) {
                    PriceText(cents: p.price)
                    Text(p.updatedAt, format: .relative(presentation: .named))
                        .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var delta: Double? {
        guard let before, let now = station.price(fuel)?.price else { return nil }
        return now - before
    }

    private var change: String {
        // Short, so the suburb stays readable; the footer says what the change is measured from.
        guard let delta else { return "\(station.suburb) · new" }
        if abs(delta) < 0.05 { return "\(station.suburb) · no change" }
        return "\(station.suburb) · \(delta < 0 ? "▼" : "▲") \(abs(delta).formatted(.number.precision(.fractionLength(1))))"
    }

    private var changeColor: Color {
        guard let delta, abs(delta) >= 0.05 else { return ServoMapColor.ink3 }
        return delta < 0 ? ServoMapColor.priceCheap : ServoMapColor.priceExpensive
    }
}
