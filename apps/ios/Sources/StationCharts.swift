import SwiftUI

/**
 * What one tank costs here, at the local average and at the cheapest station nearby, as bars on
 * a shared scale, with the saving (or the extra) stated above them.
 */
struct FillCostCard: View {
    struct Row: Identifiable {
        let label: String
        let cents: Double
        let isHere: Bool
        var id: String { label }
    }

    let litres: Int
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let here = rows.first, let average = rows.first(where: { $0.label == "Local average" }) {
                let delta = (here.cents - average.cents) * Double(litres) / 100
                Text(abs(delta) < 0.5
                     ? "About the same as the local average."
                     : "\(dollars(abs(delta))) \(delta < 0 ? "less" : "more") than the local average.")
                    .font(ServoMapFont.display(.body, weight: 500))
                    .foregroundStyle(delta < -0.5 ? ServoMapColor.priceCheap : delta > 0.5 ? ServoMapColor.priceExpensive : ServoMapColor.ink)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in bar(row) }
            }
        }
        .padding(.vertical, 6)
    }

    /** Bars start at 85% of the lowest cost, so a few dollars' difference is visible, and say so in the label. */
    private func bar(_ row: Row) -> some View {
        let costs = rows.map { $0.cents * Double(litres) / 100 }
        let lo = (costs.min() ?? 0) * 0.85
        let hi = costs.max() ?? 1
        let cost = row.cents * Double(litres) / 100
        let fraction = hi > lo ? (cost - lo) / (hi - lo) : 1
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(row.label).font(ServoMapFont.body(.footnote, weight: row.isHere ? 600 : 400)).lineLimit(1)
                Spacer()
                Text(dollars(cost)).font(ServoMapFont.body(.footnote, weight: row.isHere ? 600 : 400)).monospacedDigit()
            }
            .foregroundStyle(row.isHere ? ServoMapColor.ink : ServoMapColor.ink2)
            GeometryReader { g in
                Capsule().fill(ServoMapColor.wash)
                    .overlay(alignment: .leading) {
                        Capsule().fill(row.isHere ? ServoMapColor.ink : ServoMapColor.ink3.opacity(0.5))
                            .frame(width: max(8, g.size.width * (0.15 + 0.85 * fraction)))
                    }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

/**
 * One fuel: its price here and, underneath, where that sits in the nearby spread — a hairline from
 * the cheapest to the dearest price, a tick at the average, and this station as a dot in its tier colour.
 */
struct FuelRangeRow: View {
    let fuel: FuelType
    let cents: Double
    let nearby: [Double]
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(fuel.rawValue).font(ServoMapFont.body(.body, weight: selected ? 600 : 400))
                Spacer()
                if let avg = average {
                    let delta = cents - avg
                    Text(abs(delta) < 0.05 ? "average" : "\(delta > 0 ? "+" : "−")\(fmt1(abs(delta)))¢ vs avg")
                        .font(ServoMapFont.small).monospacedDigit()
                        .foregroundStyle(tierColor)
                }
                PriceText(cents: cents, font: ServoMapFont.lead)
            }
            if let lo = nearby.min(), let hi = nearby.max(), hi > lo {
                strip(lo: lo, hi: hi)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var average: Double? { nearby.isEmpty ? nil : nearby.reduce(0, +) / Double(nearby.count) }

    private var tierColor: Color {
        PriceRange(nearby).tier(cents).color
    }

    private func strip(lo: Double, hi: Double) -> some View {
        let x = { (v: Double) in (v - lo) / (hi - lo) }
        return VStack(spacing: 3) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    // Cheap to dear, in the tier colours at low strength.
                    Capsule()
                        .fill(LinearGradient(colors: [ServoMapColor.priceCheap, ServoMapColor.priceMid, ServoMapColor.priceExpensive],
                                             startPoint: .leading, endPoint: .trailing))
                        .opacity(0.25)
                        .frame(height: 4)
                    if let avg = average {
                        Rectangle().fill(ServoMapColor.ink3).frame(width: 1.5, height: 10).offset(x: w * x(avg) - 0.75)
                    }
                    Circle()
                        .fill(tierColor)
                        .overlay(Circle().stroke(ServoMapColor.surface, lineWidth: 2))
                        .frame(width: 12, height: 12)
                        .offset(x: min(max(w * x(cents) - 6, 0), w - 12))
                }
                .frame(height: 12)
            }
            .frame(height: 12)
            HStack {
                Text(fmt1(lo)); Spacer(); Text(fmt1(hi))
            }
            .font(ServoMapFont.label).monospacedDigit().foregroundStyle(ServoMapColor.ink3)
        }
    }
}

private func fmt1(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }
private func dollars(_ v: Double) -> String { v.formatted(.currency(code: "AUD")) }
