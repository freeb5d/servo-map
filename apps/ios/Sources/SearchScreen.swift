import SwiftUI

/**
 * Search: before typing it offers recent searches, brands and the cheapest suburbs nearby;
 * while typing it suggests matching suburbs; after submitting it lists stations with a summary.
 */
struct SearchScreen: View {
    @Environment(Store.self) private var store
    @State private var query = ""
    @State private var results: [Station] = []
    @State private var resultTitle = ""
    @State private var searched = false
    @AppStorage("recentSearches") private var recentRaw = ""

    var body: some View {
        NavigationStack {
            List {
                if searched || !results.isEmpty {
                    resultSections
                } else {
                    if !recent.isEmpty { recentSection }
                    brandSection
                    suburbSection
                }
            }
            .paperList()
            .overlay { if searched && results.isEmpty { ContentUnavailableView.search(text: query) } }
            .navigationTitle("Search")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Suburb, postcode or station")
            .searchSuggestions {
                ForEach(suggestions, id: \.self) { suburb in
                    Label(suburb, systemImage: "mappin.and.ellipse").searchCompletion(suburb)
                }
            }
            .onSubmit(of: .search) { Task { await run(query) } }
            .onChange(of: query) { if query.isEmpty { clearResults() } }
            .navigationDestination(for: Station.self) { StationDetail(station: $0) }
        }
    }

    // MARK: Before searching

    private var recentSection: some View {
        Section {
            ForEach(recent, id: \.self) { term in
                Button { query = term; Task { await run(term) } } label: {
                    Label(term, systemImage: "clock.arrow.circlepath").foregroundStyle(ServoMapColor.ink)
                }
            }
            .paperRow()
        } header: {
            HStack {
                Text("Recent")
                Spacer()
                Button("Clear") { recentRaw = "" }.font(ServoMapFont.small).textCase(nil)
            }
        }
    }

    private var brandSection: some View {
        Section("Browse by brand") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(brandStats, id: \.0.id) { family, avg, count in
                        Button { showBrand(family) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                BrandSeal(family: family)
                                Text(family.name).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink).lineLimit(1)
                                Text("\(count) · \(avg.formatted(.number.precision(.fractionLength(1))))")
                                    .font(ServoMapFont.small).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
                            }
                            .frame(width: 96, alignment: .leading)
                            .padding(12)
                            .background(ServoMapColor.bg, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .paperRow()
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        }
    }

    private var suburbSection: some View {
        Section("Cheapest suburbs nearby") {
            ForEach(suburbStats.prefix(8), id: \.suburb) { row in
                Button { query = row.suburb; Task { await run(row.suburb) } } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.suburb).foregroundStyle(ServoMapColor.ink)
                            HStack(spacing: 6) {
                                BrandSeal(family: row.cheapest.family)
                                Text("\(row.count) station\(row.count == 1 ? "" : "s")")
                                    .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                            }
                        }
                        Spacer()
                        PriceText(cents: row.low, font: ServoMapFont.lead)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ServoMapColor.ink3)
                    }
                }
            }
            .paperRow()
        }
    }

    // MARK: Results

    @ViewBuilder private var resultSections: some View {
        if let low = results.compactMap({ $0.price(store.fuel)?.price }).min() {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resultTitle).font(ServoMapFont.display(.title3, weight: 500))
                    Text("\(results.count) stations, from \(low.formatted(.number.precision(.fractionLength(1)))) ¢/L \(store.fuel.rawValue)")
                        .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                }
                .listRowBackground(Color.clear)
            }
        }
        Section {
            let range = PriceRange(results.compactMap { $0.price(store.fuel)?.price })
            ForEach(results) { station in
                NavigationLink(value: station) { StationRow(station: station, fuel: store.fuel, range: range) }
            }
            .paperRow()
        }
    }

    // MARK: Data

    private var recent: [String] { recentRaw.split(separator: "\n").map(String.init) }

    private func remember(_ term: String) {
        let next = [term] + recent.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        recentRaw = next.prefix(5).joined(separator: "\n")
    }

    private func run(_ term: String) async {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        results = ((try? await API().search(trimmed, fuel: store.fuel)) ?? [])
            .sorted { ($0.price(store.fuel)?.price ?? .infinity) < ($1.price(store.fuel)?.price ?? .infinity) }
        resultTitle = trimmed
        searched = true
        remember(trimmed)
    }

    private func showBrand(_ family: BrandFamily) {
        results = store.stations.filter { $0.family == family && $0.price(store.fuel) != nil }
            .sorted { ($0.price(store.fuel)?.price ?? .infinity) < ($1.price(store.fuel)?.price ?? .infinity) }
        resultTitle = "\(family.name) nearby"
        searched = true
    }

    private func clearResults() {
        results = []
        searched = false
    }

    private var suggestions: [String] {
        guard query.count >= 2 else { return [] }
        let all = Set(store.stations.map(\.suburb))
        return all.filter { $0.localizedCaseInsensitiveContains(query) }.sorted().prefix(6).map { $0 }
    }

    private var brandStats: [(BrandFamily, Double, Int)] {
        let rows = store.stations.compactMap { s in s.price(store.fuel).map { (s.family, $0.price) } }
        return Dictionary(grouping: rows, by: { $0.0 })
            .map { family, r in (family, r.map(\.1).reduce(0, +) / Double(r.count), r.count) }
            .sorted { $0.2 > $1.2 }
    }

    private struct SuburbRow { let suburb: String; let low: Double; let count: Int; let cheapest: Station }

    private var suburbStats: [SuburbRow] {
        Dictionary(grouping: store.stations.filter { $0.price(store.fuel) != nil }, by: \.suburb)
            .compactMap { suburb, stations in
                let sorted = stations.sorted { $0.price(store.fuel)!.price < $1.price(store.fuel)!.price }
                guard let first = sorted.first, let low = first.price(store.fuel)?.price else { return nil }
                return SuburbRow(suburb: suburb, low: low, count: stations.count, cheapest: first)
            }
            .sorted { $0.low < $1.low }
    }
}
