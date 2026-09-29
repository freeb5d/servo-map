import SwiftUI
import WidgetKit

// Shared by the widget extension and the app's widget gallery (`-widgets`), so the gallery
// screenshots show exactly what the widgets draw.

struct PriceEntry: TimelineEntry {
    let date: Date
    let fuel: FuelType
    let stations: [Station]
    let verdict: String?
}

struct PriceWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    let entry: PriceEntry
    /** Lets the app's widget gallery draw every size; widgets themselves leave it nil. */
    var familyOverride: WidgetFamily?

    private var family: WidgetFamily { familyOverride ?? systemFamily }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
    }

    private var best: Station? { entry.stations.first }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cheapest \(entry.fuel.rawValue)").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            if let best, let p = best.price(entry.fuel) {
                Text(p.price, format: .number.precision(.fractionLength(1)))
                    .font(ServoMapFont.display(.largeTitle, size: 36)).minimumScaleFactor(0.6).lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    BrandSeal(family: best.family)
                    Text(best.suburb).font(ServoMapFont.small).lineLimit(1)
                }
                Text(p.updatedAt, format: .relative(presentation: .named)).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            } else {
                Spacer()
                Text("No prices right now").font(ServoMapFont.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(entry.fuel.rawValue) near \(Nearby.place)").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                Spacer()
                if let verdict = entry.verdict { Text(verdict).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink2).lineLimit(1) }
            }
            ForEach(entry.stations) { station in
                HStack(spacing: 8) {
                    BrandSeal(family: station.family)
                    Text(station.name).font(ServoMapFont.body).lineLimit(1)
                    Spacer()
                    if let p = station.price(entry.fuel) {
                        Text(p.price, format: .number.precision(.fractionLength(1))).font(ServoMapFont.display(.body))
                    }
                }
                if station != entry.stations.last { Divider() }
            }
            Spacer(minLength: 0)
        }
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Text(entry.fuel.rawValue).font(.system(size: 9, weight: .semibold))
            if let p = best?.price(entry.fuel) {
                // Prices differ by tenths of a cent, so the round face keeps the decimal at a smaller size.
                Text(p.price, format: .number.precision(.fractionLength(1))).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
        }
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(entry.fuel.rawValue) near \(Nearby.place)").font(.caption2)
            if let best, let p = best.price(entry.fuel) {
                Text("\(p.price.formatted(.number.precision(.fractionLength(1)))) at \(best.suburb)").font(.headline).lineLimit(1)
            }
            if let verdict = entry.verdict { Text(verdict).font(.caption2).lineLimit(1) }
        }
    }
}

