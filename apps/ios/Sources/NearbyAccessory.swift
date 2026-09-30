import SwiftUI

/**
 * The tab bar's accessory on Nearby: the cheapest station on the map in one line. Tapping it
 * raises the full list. Folded beside a minimised bar, it keeps only the price and the brand.
 */
struct NearbyAccessory: View {
    @Environment(Store.self) private var store
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: ServoMapSpace.x3) {
                if let cheapest = store.cheapestInView, let p = cheapest.price(store.fuel) {
                    BrandSeal(family: cheapest.family, size: 24)
                    if placement != .inline {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Cheapest \(store.fuel.rawValue) on the map")
                                .font(ServoMapFont.body(.caption, weight: 600)).foregroundStyle(ServoMapColor.priceCheap)
                            Text(cheapest.suburb).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink2)
                        }
                        .lineLimit(1)
                    }
                    Spacer(minLength: ServoMapSpace.x2)
                    PriceText(cents: p.price, font: ServoMapFont.display(.body, size: 19))
                } else {
                    Text(emptyText).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2).lineLimit(1)
                    Spacer(minLength: ServoMapSpace.x2)
                }
                Image(systemName: "list.bullet").font(ServoMapFont.body(.body, weight: 600))
            }
            .foregroundStyle(ServoMapColor.ink)
            .padding(.horizontal, ServoMapSpace.x4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Shows every station on the map, cheapest first")
    }

    private var emptyText: String {
        if store.loading && store.stations.isEmpty { return "Loading prices" }
        if store.failed && store.stations.isEmpty { return "Prices didn’t load" }
        return store.ranked.isEmpty ? "No prices here" : "No stations on this part of the map"
    }

    private var accessibilityText: String {
        guard let cheapest = store.cheapestInView, let p = cheapest.price(store.fuel) else { return emptyText }
        return "Cheapest \(store.fuel.rawValue) on the map: \(cheapest.name), \(p.price.formatted(.number.precision(.fractionLength(1)))) cents"
    }
}
