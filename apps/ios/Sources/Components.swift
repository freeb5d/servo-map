import SwiftUI
import UIKit

/**
 * Brand mark (decision 0003): the brand's own logo on a white tile where the app bundles one, and
 * otherwise its monogram on a tile in the brand colour with an optional second-colour stripe.
 */
struct BrandSeal: View {
    let family: BrandFamily
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let logo = UIImage(named: "brand-\(family.id)") {
                logoTile(logo)
            } else {
                monogram
            }
        }
        .accessibilityLabel(family.name)
        // A mark, not reading text: it keeps its size at every Dynamic Type setting.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: size * 0.24, style: .continuous) }

    /** The brand's own logo (generated into Resources/Assets.xcassets/BrandLogos from design/brand-logos) on a white tile, as on a price sign. */
    private func logoTile(_ logo: UIImage) -> some View {
        Image(uiImage: logo)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .padding(size * 0.1)
            .frame(width: size, height: size)
            .background(ServoMapColor.brandTile, in: shape)
            .overlay(shape.strokeBorder(ServoMapColor.brandTileLine, lineWidth: 0.5))
            .overlay { membersRing }
    }

    /** Brands without a logo file: the monogram on a tile in the brand colour. */
    private var monogram: some View {
        let mark = family.mark
        return Text(family.seal)
            .font(.system(size: size * (family.seal.count > 2 ? 0.3 : 0.38), weight: .heavy, design: .rounded))
            .tracking(-0.2)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .foregroundStyle(Color(brand: mark.foreground))
            .padding(.horizontal, 2)
            .frame(width: size, height: size)
            .background {
                ZStack(alignment: .bottom) {
                    Color(brand: mark.background)
                    if let stripe = mark.stripe {
                        Color(brand: stripe).frame(height: size * 0.14)
                    }
                }
            }
            .clipShape(shape)
            .overlay { membersRing }
    }

    /** Members-only brands (Costco) get a dashed ring: you need a membership to fill up there. */
    @ViewBuilder private var membersRing: some View {
        if family.group == .members {
            shape.inset(by: -2.5).stroke(ServoMapColor.ink3, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
    }
}

extension Color {
    /** A fixed brand colour: signs look the same by day and night. */
    init(brand rgb: UInt32) {
        self.init(light: rgb, dark: rgb)
    }
}

/** Price in the serif face with a small unit, the one typographic flourish in the app. */
struct PriceText: View {
    let cents: Double
    var font: Font = ServoMapFont.price
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(cents, format: .number.precision(.fractionLength(1))).font(font).monospacedDigit()
                // A new price cross-fades (the system's opacity motion) rather than jumping.
                .contentTransition(.opacity)
                .animation(ServoMapMotion.standard, value: cents)
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
    /** Position in a cheapest-first list; shown before the mark when set. */
    var rank: Int? = nil
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
                    if let rank {
                        Text("\(rank)")
                            .font(ServoMapFont.body(.footnote, weight: rank == 1 ? 700 : 500)).monospacedDigit()
                            .foregroundStyle(rank == 1 ? ServoMapColor.priceCheap : ServoMapColor.ink3)
                            .frame(minWidth: 18, alignment: .trailing)
                    }
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
