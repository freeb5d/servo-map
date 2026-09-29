import SwiftUI

/** Brand seal (判子): the family monogram in a hairline box. Dashed for members-only brands. */
struct BrandSeal: View {
    let family: BrandFamily
    var body: some View {
        Text(family.seal)
            .font(ServoMapFont.body(.caption2, weight: 700, size: 9))
            .tracking(0.4)
            .foregroundStyle(ServoMapColor.ink)
            .frame(minWidth: 28, minHeight: 18)
            .padding(.horizontal, 2)
            .overlay(
                RoundedRectangle(cornerRadius: ServoMapRadius.r1)
                    .strokeBorder(ServoMapColor.ink2, style: StrokeStyle(lineWidth: 1, dash: family.group == .members ? [2, 2] : []))
            )
            .accessibilityLabel(family.name)
            // The seal is a mark, not reading text; past xLarge it would crowd the row.
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }
}

/** Price in the serif face with a small unit, the one typographic flourish in the app. */
struct PriceText: View {
    let cents: Double
    var font: Font = ServoMapFont.price
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(cents, format: .number.precision(.fractionLength(1))).font(font).monospacedDigit()
            Text("¢/L").font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
        }
    }
}

struct TierText: View {
    let tier: PriceTier
    var body: some View {
        Text(tier.rawValue)
            .font(ServoMapFont.small.weight(.medium))
            .foregroundStyle(tier.color)
    }
}

extension PriceTier {
    var color: Color {
        switch self {
        case .cheap: ServoMapColor.priceCheap
        case .fair: ServoMapColor.priceMid
        case .pricey: ServoMapColor.priceExpensive
        }
    }
}

struct StationRow: View {
    let station: Station
    let fuel: FuelType
    let range: PriceRange
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            // At accessibility sizes the one-line row cannot fit; stack it and let the name wrap.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    BrandSeal(family: station.family)
                    names(lineLimit: 3)
                    price
                }
            } else {
                HStack(spacing: 12) {
                    BrandSeal(family: station.family)
                    names(lineLimit: 1)
                    Spacer(minLength: 8)
                    price.frame(alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func names(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(station.name).font(ServoMapFont.lead).lineLimit(lineLimit)
            Text(detail).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3).lineLimit(lineLimit)
        }
    }

    @ViewBuilder private var price: some View {
        if let p = station.price(fuel) {
            VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                PriceText(cents: p.price)
                TierText(tier: range.tier(p.price))
            }
        }
    }

    private var detail: String {
        guard let km = station.distance else { return station.suburb }
        return "\(station.suburb), \(km.formatted(.number.precision(.fractionLength(1)))) km"
    }
}

/** Page background and row fill in the paper tones, so lists read as 素 rather than stock grey. */
extension View {
    func paperList() -> some View {
        scrollContentBackground(.hidden).background(ServoMapColor.bg)
    }

    /**
     * A list row on paper at body size. The app's default font is the small caption size so that
     * section headers and footers come out small; rows opt back up to body size here.
     */
    func paperRow() -> some View {
        listRowBackground(ServoMapColor.surface).font(ServoMapFont.lead)
    }
}

/** Card heading in the Health manner: a symbol and title on the left, a quiet note on the right. */
struct CardHeader: View {
    let title: String
    let symbol: String
    var note: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).imageScale(.small)
            Text(title).font(ServoMapFont.body(.subheadline, weight: 500))
            Spacer(minLength: 8)
            if let note { Text(note).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3) }
        }
        .foregroundStyle(ServoMapColor.ink2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/** A section title set in the display face, for grouping cards the way Health groups Highlights. */
struct GroupTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(ServoMapFont.display(.title3, weight: 600)).foregroundStyle(ServoMapColor.ink).textCase(nil)
            .padding(.leading, -4)
    }
}
