import AppIntents
import SwiftUI
import WidgetKit

struct PriceWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Fuel prices"
    static let description = IntentDescription("The cheapest fuel near Sydney CBD.")

    @Parameter(title: "Fuel", default: .u91)
    var fuel: FuelType
}

struct PriceProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PriceEntry {
        PriceEntry(date: .now, fuel: .u91, stations: [.placeholder(0), .placeholder(1), .placeholder(2)], verdict: "Near the 90-day high.")
    }

    func snapshot(for configuration: PriceWidgetIntent, in context: Context) async -> PriceEntry {
        context.isPreview ? placeholder(in: context) : await entry(for: configuration.fuel)
    }

    func timeline(for configuration: PriceWidgetIntent, in context: Context) async -> Timeline<PriceEntry> {
        // Feeds update every 15 minutes upstream; half an hour keeps the widget fresh without waste.
        Timeline(entries: [await entry(for: configuration.fuel)], policy: .after(.now.addingTimeInterval(30 * 60)))
    }

    private func entry(for fuel: FuelType) async -> PriceEntry {
        async let stations = (try? await Nearby.cheapest(fuel)) ?? []
        async let history = (try? await API().trends(state: "nsw")) ?? []
        let verdict = TrendMath.verdict(await history.filter { $0.fuel == fuel.rawValue })
        return PriceEntry(date: .now, fuel: fuel, stations: await stations, verdict: verdict)
    }
}

struct PriceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PriceWidget", intent: PriceWidgetIntent.self, provider: PriceProvider()) { entry in
            PriceWidgetView(entry: entry)
                .containerBackground(ServoMapColor.surface, for: .widget)
        }
        .configurationDisplayName("Cheapest fuel")
        .description("The cheapest fuel near you and where prices sit in the cycle.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct ServoMapWidgets: WidgetBundle {
    var body: some Widget { PriceWidget() }
}
