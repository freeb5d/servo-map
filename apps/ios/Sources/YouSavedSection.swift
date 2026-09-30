import SwiftUI

/**
 * Saved stations on You: one price scale showing where each sits among the current prices nearby,
 * then ledger rows, cheapest first (docs/design/system.md, Ledger row).
 */
struct YouSavedSection: View {
    /** Rows shown here; "All" opens the Saved page for the rest. */
    static let rows = 5
    @Environment(Store.self) private var store

    var body: some View {
        let fuel = store.fuel
        let now = Date.now
        let current = store.stations.filter { $0.hasCurrentPrice(fuel, now: now) }
        let saved = current.filter(store.isSaved)
            .sorted { ($0.price(fuel)?.price ?? .infinity) < ($1.price(fuel)?.price ?? .infinity) }
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "Saved") {
                if !store.savedIDs.isEmpty { NavigationLink("All \(store.savedIDs.count)", value: YouScreen.Page.saved) }
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { Hairline() }
            if saved.isEmpty {
                Text(store.savedIDs.isEmpty
                     ? "Save a station from its page and it shows up here with its price."
                     : "Your saved stations have no current \(fuel.rawValue) price in the area on the map.")
                    .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                    .padding(.top, 10)
            } else {
                let prices = current.compactMap { $0.price(fuel)?.price }
                if let low = prices.min(), let high = prices.max(), high > low {
                    SavedScale(saved: saved, fuel: fuel, low: low, high: high, range: store.range, radiusKm: store.radiusKm)
                        .frame(height: 54)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }
                ForEach(Array(saved.prefix(Self.rows).enumerated()), id: \.element.id) { index, station in
                    NavigationLink(value: station) {
                        SavedLedgerRow(station: station, fuel: fuel, tier: store.range.tier(station.price(fuel)?.price ?? 0),
                                       cheapest: index == 0 && saved.count > 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/**
 * Where each saved station's price sits between the cheapest and dearest current price nearby.
 * The ground under the line marks the cheap, fair and pricey thirds.
 */
private struct SavedScale: View {
    let saved: [Station]
    let fuel: FuelType
    let low: Double
    let high: Double
    let range: PriceRange
    let radiusKm: Int

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let x = { (price: Double) in w * min(max((price - low) / (high - low), 0), 1) }
            ZStack(alignment: .topLeading) {
                bands(cheapEnd: x(range.cheapBelow), fairEnd: x(range.midBelow), width: w).offset(y: 24)
                ForEach(Array(placed(x, width: w).enumerated()), id: \.element.station.id) { index, mark in
                    Circle().fill(index == 0 ? ServoMapColor.priceCheap : ServoMapColor.ink)
                        .overlay(Circle().strokeBorder(ServoMapColor.bg, lineWidth: 2.5))
                        .frame(width: 16, height: 16)
                        .offset(x: mark.x - 8, y: 18)
                    Text(mark.station.family.seal)
                        .font(ServoMapFont.body(.caption2, weight: 700, size: 10))
                        .fixedSize()
                        .offset(x: mark.labelX, y: 0)
                }
                HStack {
                    Text(low.formatted(.number.precision(.fractionLength(1))))
                    Spacer()
                    Text("\(fuel.rawValue) within \(radiusKm) km")
                    Spacer()
                    Text(high.formatted(.number.precision(.fractionLength(1))))
                }
                .font(ServoMapFont.label).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
                .frame(width: w)
                .offset(y: 38)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Current \(fuel.rawValue) prices within \(radiusKm) km run from \(low.formatted(.number.precision(.fractionLength(1)))) to \(high.formatted(.number.precision(.fractionLength(1)))) cents")
    }

    private func bands(cheapEnd: CGFloat, fairEnd: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ServoMapColor.priceCheapSoft.frame(width: max(cheapEnd, 0))
            ServoMapColor.priceMidSoft.frame(width: max(fairEnd - cheapEnd, 0))
            ServoMapColor.priceExpensiveSoft
        }
        .frame(width: width, height: 4)
        .clipShape(RoundedRectangle(cornerRadius: ServoMapRadius.r1))
    }

    /** Dots left to right; a label that would collide with the one before moves to the dot's right. */
    private func placed(_ x: (Double) -> CGFloat, width total: CGFloat) -> [(station: Station, x: CGFloat, labelX: CGFloat)] {
        var lastEnd = -CGFloat.infinity
        return saved.compactMap { station in
            guard let price = station.price(fuel)?.price else { return nil }
            let dot = x(price)
            let width = CGFloat(station.family.seal.count) * 7
            var labelX = dot - width / 2
            if labelX < lastEnd + 2 { labelX = max(dot + 4, lastEnd + 2) }
            labelX = min(max(labelX, 0), total - width)
            lastEnd = labelX + width
            return (station, dot, labelX)
        }
    }
}

/** A saved station as a ledger row; the cheapest saved sits on the cheap tier's soft fill. */
private struct SavedLedgerRow: View {
    let station: Station
    let fuel: FuelType
    let tier: PriceTier
    let cheapest: Bool

    var body: some View {
        HStack(spacing: 12) {
            BrandSeal(family: station.family, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(station.name).font(ServoMapFont.body(.callout)).lineLimit(1)
                Text(detail).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3).lineLimit(1)
            }
            Spacer(minLength: 8)
            if let p = station.price(fuel) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(p.price.formatted(.number.precision(.fractionLength(1))))
                        .font(ServoMapFont.display(.title3)).monospacedDigit()
                    if cheapest {
                        Text("Cheapest saved").font(ServoMapFont.small.weight(.semibold)).foregroundStyle(ServoMapColor.priceCheap)
                    } else {
                        TierText(tier: tier)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(cheapest ? ServoMapColor.priceCheapSoft : .clear)
        .overlay(alignment: .bottom) { Hairline().padding(.horizontal, 20) }
        .padding(.horizontal, -20)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        guard let p = station.price(fuel) else { return station.suburb }
        return "\(station.suburb) · updated \(p.updatedAt.formatted(.relative(presentation: .named)))"
    }
}
