import SwiftUI

/** The full list of nearby stations, cheapest first, with the station page pushed inside. */
struct ResultsSheet: View {
    @Environment(Store.self) private var store
    @Binding var selected: Station?
    @Binding var showFilters: Bool

    var body: some View {
        NavigationStack {
            List {
                Section { verdict }
                if store.stations.isEmpty && store.loading {
                    placeholderRows
                } else if !store.ranked.isEmpty {
                    Section {
                        ForEach(store.ranked.prefix(60)) { station in
                            NavigationLink(value: station) {
                                StationRow(station: station, fuel: store.fuel, range: store.range)
                            }
                            .paperRow()
                        }
                    } header: {
                        Text("\(store.ranked.count) stations, cheapest first")
                    }
                }
            }
            .paperList()
            .navigationDestination(for: Station.self) { StationDetail(station: $0) }
            .navigationDestination(item: $selected) { StationDetail(station: $0) }
            .sheet(isPresented: $showFilters) { FilterSheet() }
            .overlay {
                if store.failed && store.stations.isEmpty { failure }
                else if store.stations.isEmpty && !store.loading { noCoverage }
                else if !store.stations.isEmpty && store.ranked.isEmpty { noMatch }
            }
        }
    }

    @ViewBuilder private var verdict: some View {
        if let cheapest = store.ranked.first, let p = cheapest.price(store.fuel) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(store.fuel.rawValue) near \(store.placeName)").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    PriceText(cents: p.price, font: ServoMapFont.display(.largeTitle))
                    BrandSeal(family: cheapest.family)
                    Text(cheapest.suburb).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                }
                if let line = store.verdictLine {
                    Text(line).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                }
            }
            .paperRow()
        }
    }

    /** Shape of the list while the first prices load, so the sheet never opens empty. */
    private var placeholderRows: some View {
        Section {
            ForEach(0..<6, id: \.self) { i in
                StationRow(station: .placeholder(i), fuel: store.fuel, range: PriceRange([]))
                    .redacted(reason: .placeholder)
                    .paperRow()
            }
        }
        .accessibilityLabel("Loading prices")
    }

    /** An area with no reporting stations: say so and offer the way back, instead of a blank sheet. */
    private var noCoverage: some View {
        ContentUnavailableView {
            Label("No prices here yet", systemImage: "fuelpump.slash")
        } description: {
            Text(coverageText)
        } actions: {
            Button("Back to Sydney CBD") {
                Task { await store.move(to: Store.sydney.lat, Store.sydney.lng, name: "Sydney CBD") }
            }
            .buttonStyle(.glassProminent)
        }
    }

    private var coverageText: String {
        let live = ListFormatter.localizedString(byJoining: store.liveStates)
        return live.isEmpty
            ? "Move the map to another area or search a suburb."
            : "Live prices cover \(live) today. Move the map there or search a suburb."
    }

    private var noMatch: some View {
        ContentUnavailableView {
            Label("No stations match", systemImage: "line.3.horizontal.decrease")
        } description: {
            Text("\(store.stations.count) stations are nearby, but none pass your filters.")
        } actions: {
            Button("Reset filters") { store.filters = Filters() }.buttonStyle(.glassProminent)
        }
    }

    private var failure: some View {
        ContentUnavailableView {
            Label("Prices didn’t load", systemImage: "wifi.exclamationmark")
        } description: {
            Text("Check your connection, then try again.")
        } actions: {
            Button("Try again") { Task { await store.load() } }.buttonStyle(.glassProminent)
        }
    }
}
