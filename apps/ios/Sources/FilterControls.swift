import SwiftUI

/** The brands in the loaded data as a grid of 1:1 marks; each one on or off. */
struct BrandGrid: View {
    @Binding var filters: Filters
    let present: [BrandFamily]

    private static let tile: CGFloat = 56
    private let columns = Array(repeating: GridItem(.flexible(), spacing: ServoMapSpace.x2), count: 4)

    var body: some View {
        let on = present.filter { BrandChoice.isOn($0.id, in: filters) }.count
        VStack(alignment: .leading, spacing: ServoMapSpace.x3) {
            FilterTitle("Brands", note: BrandChoice.countLine(on: on, of: present.count))
            LazyVGrid(columns: columns, spacing: ServoMapSpace.x3) {
                ForEach(present) { family in tile(family) }
            }
        }
    }

    private func tile(_ family: BrandFamily) -> some View {
        let on = BrandChoice.isOn(family.id, in: filters)
        return Button {
            withAnimation(.snappy) { BrandChoice.toggle(family.id, in: &filters, among: present.map(\.id)) }
        } label: {
            VStack(spacing: 6) {
                BrandSeal(family: family, size: Self.tile)
                    .overlay {
                        BrandSeal.shape(Self.tile)
                            .strokeBorder(ServoMapColor.accent, lineWidth: 2)
                            .opacity(on ? 1 : 0)
                    }
                Text(family.name)
                    .font(ServoMapFont.small)
                    .foregroundStyle(ServoMapColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .opacity(on ? 1 : 0.45)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(family.name)
        .accessibilityValue(on ? "Shown" : "Hidden")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/** Stations in view per price band, each bar in its tier's colour; a hidden tier's bars fade to the line colour. */
struct TierHistogram: View {
    let histogram: PriceHistogram
    let range: PriceRange
    let hidden: Set<PriceTier>

    private static let height: CGFloat = 56

    var body: some View {
        if let low = histogram.low, let high = histogram.high {
            VStack(spacing: ServoMapSpace.x1) {
                bars
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int(low.rounded(.down)))¢")
                    Spacer(minLength: ServoMapSpace.x2)
                    Text(PriceHistogram.cutLine(range))
                    Spacer(minLength: ServoMapSpace.x2)
                    Text("\(Int(high.rounded(.up)))¢")
                }
                .font(ServoMapFont.label)
                .monospacedDigit()
                .foregroundStyle(ServoMapColor.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Prices in view, \(Int(low.rounded(.down))) to \(Int(high.rounded(.up))) cents")
            .accessibilityValue(PriceHistogram.cutLine(range))
        } else {
            Text("No current prices in view.")
                .font(ServoMapFont.body)
                .foregroundStyle(ServoMapColor.ink3)
                .frame(maxWidth: .infinity, minHeight: Self.height, alignment: .leading)
        }
    }

    private var bars: some View {
        let top = Double(max(1, histogram.tallest))
        return HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(histogram.bins.enumerated()), id: \.offset) { _, bin in
                let tier = range.tier(bin.mid)
                UnevenRoundedRectangle(topLeadingRadius: ServoMapRadius.r1, topTrailingRadius: ServoMapRadius.r1)
                    .fill(hidden.contains(tier) ? ServoMapColor.line : tier.color.opacity(0.85))
                    .frame(height: Self.height * Double(bin.count) / top)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: Self.height, alignment: .bottom)
        .overlay(alignment: .bottom) { Hairline() }
        .animation(.smooth, value: hidden)
        .animation(.smooth, value: histogram)
    }
}

/** Cheap, Fair and Pricey as toggles; all on shows every price. */
struct TierChips: View {
    @Binding var hidden: Set<PriceTier>

    var body: some View {
        HStack(spacing: ServoMapSpace.x2) {
            ForEach([PriceTier.cheap, .fair, .pricey], id: \.self) { chip($0) }
        }
    }

    private func chip(_ tier: PriceTier) -> some View {
        let on = !hidden.contains(tier)
        return Button {
            withAnimation(.snappy) {
                if on { hidden.insert(tier) } else { hidden.remove(tier) }
            }
        } label: {
            HStack(spacing: ServoMapSpace.x2) {
                Rectangle().fill(tier.color).frame(width: 9, height: 9)
                Text(tier.rawValue)
            }
            .font(ServoMapFont.body(.subheadline, weight: on ? 600 : 400))
            .foregroundStyle(on ? ServoMapColor.ink : ServoMapColor.ink2)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(on ? tier.softColor : ServoMapColor.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(on ? ServoMapColor.accent : ServoMapColor.line, lineWidth: on ? 1.5 : 0.5))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tier.rawValue) prices")
        .accessibilityValue(on ? "Shown" : "Hidden")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private extension PriceTier {
    var softColor: Color {
        switch self {
        case .cheap: ServoMapColor.priceCheapSoft
        case .fair: ServoMapColor.priceMidSoft
        case .pricey: ServoMapColor.priceExpensiveSoft
        }
    }
}

/** How recently a price was reported, as four dots on a scale; tap or drag along it. */
struct FreshnessScale: View {
    @Binding var hours: Int?

    /** Keeps the outer labels ("6 h", "A week") inside the margins when centred on their dots. */
    private static let inset: CGFloat = 20
    private static let steps = FreshnessStep.allCases

    var body: some View {
        let current = FreshnessStep(hours: hours)
        VStack(alignment: .leading, spacing: ServoMapSpace.x3) {
            HStack(alignment: .firstTextBaseline) {
                FilterTitle("Reported within")
                Text(current.long)
                    .font(ServoMapFont.display(.body, weight: 600))
                    .foregroundStyle(ServoMapColor.ink)
                    .contentTransition(.opacity)
            }
            GeometryReader { geo in
                let span = geo.size.width - Self.inset * 2
                ZStack(alignment: .topLeading) {
                    Hairline()
                        .frame(width: span)
                        .offset(x: Self.inset, y: 9)
                    ForEach(Self.steps) { step in
                        let x = Self.inset + span * Double(step.rawValue) / Double(Self.steps.count - 1)
                        dot(step, current: current).position(x: x, y: 9)
                        Text(step.short)
                            .font(ServoMapFont.label.weight(step == current ? .semibold : .regular))
                            .foregroundStyle(step == current ? ServoMapColor.ink : ServoMapColor.ink3)
                            .fixedSize()
                            .position(x: x, y: 32)
                    }
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let fraction = (value.location.x - Self.inset) / max(1, span)
                    let index = Int((fraction * Double(Self.steps.count - 1)).rounded())
                    let step = Self.steps[min(max(index, 0), Self.steps.count - 1)]
                    if step != current { withAnimation(.snappy) { hours = step.hours } }
                })
            }
            .frame(height: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reported within")
            .accessibilityValue(current.long)
            .accessibilityAdjustableAction { direction in
                let next = current.rawValue + (direction == .increment ? 1 : -1)
                if let step = FreshnessStep(rawValue: next) { hours = step.hours }
            }
        }
    }

    /** Steps inside the chosen window fill in the line colour; the chosen one is a larger ink dot. */
    @ViewBuilder private func dot(_ step: FreshnessStep, current: FreshnessStep) -> some View {
        if step == current {
            Circle().fill(ServoMapColor.accent).frame(width: 18, height: 18)
        } else if step.rawValue < current.rawValue {
            Circle().fill(ServoMapColor.line).frame(width: 14, height: 14)
        } else {
            Circle().fill(ServoMapColor.surface)
                .overlay(Circle().strokeBorder(ServoMapColor.line, lineWidth: 1))
                .frame(width: 14, height: 14)
        }
    }
}
