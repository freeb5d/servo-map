import SwiftUI

/** The four Trends sub-pages (decision 0008). */
enum TrendsPage: String, CaseIterable, Identifiable {
    case overview, states, cities, timing
    var id: String { rawValue }
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/**
 * Trends: four sub-pages under a glass segmented bar below the large title. Overview and States read
 * each live state's daily series; Cities and Timing read today's city figures from the worker.
 */
struct TrendsScreen: View {
    @Environment(Store.self) private var store
    @State private var data = TrendsData()
    // `-trendsPage cities` and `-trendsState wa` open a given page, so design screenshots are reproducible.
    @State private var page = TrendsPage(rawValue: UserDefaults.standard.string(forKey: StorageKey.trendsPage) ?? "") ?? .overview
    @State private var state = UserDefaults.standard.string(forKey: StorageKey.trendsState) ?? "nsw"

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch page {
                    case .overview:
                        OverviewPage(data: data, fuel: $store.fuel) { code in
                            state = code
                            withAnimation(ServoMapMotion.snappy) { page = .states }
                        }
                    case .states:
                        StatesPage(data: data, states: liveStates, state: $state, fuel: $store.fuel)
                    case .cities:
                        CitiesPage(cities: data.cities[store.fuel], failed: data.failed, fuel: store.fuel)
                    case .timing:
                        TimingPage(cities: data.cities[store.fuel], failed: data.failed, fuel: store.fuel, state: state)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(page)
                .transition(.opacity)
            }
            .background(ServoMapColor.bg)
            .navigationTitle("Trends")
            .safeAreaBar(edge: .top) {
                PageBar(page: $page).padding(.horizontal, 16).padding(.bottom, 8)
            }
            .refreshable {
                await data.load(states: store.liveStates)
                await data.loadCities(store.fuel)
            }
            .task(id: store.liveStates) { await data.load(states: store.liveStates) }
            .task(id: store.fuel) { await data.loadCities(store.fuel) }
        }
    }

    /** Live states, biggest first, as the Overview orders them; NSW until metadata arrives. */
    private var liveStates: [String] {
        let rows = StateFacts.latest(data.byState(store.fuel)).map(\.state)
        return rows.isEmpty ? ["nsw"] : rows
    }
}

/** The sub-page switcher: a Liquid Glass capsule with the selected page filled in ink. */
private struct PageBar: View {
    @Binding var page: TrendsPage
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrendsPage.allCases) { item in
                let selected = item == page
                Button { withAnimation(ServoMapMotion.snappy) { page = item } } label: {
                    Text(item.title)
                        .font(ServoMapFont.body(.subheadline, weight: selected ? 600 : 400))
                        .foregroundStyle(selected ? ServoMapColor.onAccent : ServoMapColor.ink)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selected { Capsule().fill(ServoMapColor.accent).matchedGeometryEffect(id: "page", in: selection) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .glassEffect(.regular.interactive(), in: .capsule)
        .sensoryFeedback(.selection, trigger: page)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trends pages")
    }
}
