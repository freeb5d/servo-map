import SwiftUI

/**
 * Filters as a sheet over the map (decision 0008): order, brands as a grid of their marks, the
 * price distribution in view coloured by tier, how recently prices were reported, members-only.
 * Every control writes `store.filters`, so the map and the list follow while the sheet is open.
 */
struct FilterSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var detent: PresentationDetent = .large

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: ServoMapSpace.x5) {
                    order
                    BrandGrid(filters: $store.filters, present: BrandChoice.present(in: store.stations))
                    priceSection
                    FreshnessScale(hours: $store.filters.freshHours)
                    membersOnly
                }
                .padding(.horizontal, Self.gutter)
                .padding(.top, ServoMapSpace.x4)
                .padding(.bottom, ServoMapSpace.x5)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { showButton }
        .background(ServoMapColor.bg)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(ServoMapColor.bg)
        .sensoryFeedback(.selection, trigger: store.filters)
    }

    /** The artboard's side margin. */
    static let gutter: CGFloat = 20

    private var header: some View {
        HStack(alignment: .center) {
            Text("Filters")
                .font(ServoMapFont.display(.title2, weight: 500, size: 26))
                .foregroundStyle(ServoMapColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Reset") { withAnimation(.snappy) { store.filters = Filters() } }
                .buttonStyle(.glass)
                .actionFont()
                .disabled(store.filters == Filters())
        }
        .padding(.leading, Self.gutter)
        .padding(.trailing, ServoMapSpace.x4)
        .padding(.top, ServoMapSpace.x6)
    }

    private var order: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: ServoMapSpace.x2) {
            FilterTitle("Order")
            Picker("Order", selection: $store.filters.order) {
                ForEach(StationOrder.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var priceSection: some View {
        @Bindable var store = store
        let prices = PriceHistogram.pricesInView(store.stations, fuel: store.fuel, viewport: store.viewport)
        return VStack(alignment: .leading, spacing: ServoMapSpace.x2) {
            FilterTitle("Price", note: "\(prices.count) in view")
            TierHistogram(histogram: PriceHistogram(prices), range: store.range, hidden: store.filters.hiddenTiers)
            TierChips(hidden: $store.filters.hiddenTiers)
                .padding(.top, ServoMapSpace.x1)
        }
    }

    private var membersOnly: some View {
        @Bindable var store = store
        return Toggle(isOn: $store.filters.hideMembersOnly.animation(.snappy)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hide members-only stations").font(ServoMapFont.lead).foregroundStyle(ServoMapColor.ink)
                Text("Costco and other warehouse clubs").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .tint(ServoMapColor.accent)
        .padding(.vertical, ServoMapSpace.x3)
        .overlay(alignment: .top) { Hairline() }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var showButton: some View {
        let title = ShowStations.title(inView: store.inView.count, ranked: store.ranked.count)
        return Button { dismiss() } label: {
            Text(title)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .actionFont()
        .disabled(store.ranked.isEmpty)
        .animation(.snappy, value: title)
        .padding(.horizontal, Self.gutter)
        .padding(.top, ServoMapSpace.x3)
        .padding(.bottom, ServoMapSpace.x2)
    }
}

/** A section title in Mincho, with an optional quiet note on the right. */
struct FilterTitle: View {
    let text: String
    var note: String? = nil

    init(_ text: String, note: String? = nil) {
        self.text = text
        self.note = note
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(ServoMapFont.display(.headline, weight: 600, size: 18))
                .foregroundStyle(ServoMapColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: ServoMapSpace.x2)
            if let note {
                Text(note)
                    .font(ServoMapFont.body(.footnote))
                    .foregroundStyle(ServoMapColor.ink3)
                    .contentTransition(.numericText())
            }
        }
    }
}

/** A 0.5 pt rule in the line colour. */
struct Hairline: View {
    var body: some View {
        Rectangle().fill(ServoMapColor.line).frame(height: 0.5)
    }
}
