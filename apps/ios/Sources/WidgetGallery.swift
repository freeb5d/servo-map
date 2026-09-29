import SwiftUI
import WidgetKit

/**
 * Every widget size drawn with live data, opened with the `-widgets` launch argument. It exists so
 * widget design can be reviewed and screenshotted without placing widgets on a Home Screen by hand.
 */
struct WidgetGallery: View {
    @State private var entry = PriceEntry(date: .now, fuel: .u91, stations: [], verdict: nil)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Widgets").font(ServoMapFont.display(.largeTitle, weight: 500))
                HStack(alignment: .top, spacing: 16) {
                    tile(.systemSmall, CGSize(width: 170, height: 170), "Small")
                    VStack(alignment: .leading, spacing: 16) {
                        tile(.accessoryCircular, CGSize(width: 76, height: 76), "Lock Screen, round", dark: true)
                    }
                }
                tile(.systemMedium, CGSize(width: 364, height: 170), "Medium")
                tile(.accessoryRectangular, CGSize(width: 172, height: 76), "Lock Screen, rectangle", dark: true)
            }
            .padding(20)
        }
        .background(Color(white: 0.55))
        .task { entry = await Self.load() }
    }

    private func tile(_ family: WidgetFamily, _ size: CGSize, _ title: String, dark: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PriceWidgetView(entry: entry, familyOverride: family)
                .padding(dark ? 8 : 14)
                .frame(width: size.width, height: size.height)
                .foregroundStyle(dark ? Color.white : ServoMapColor.ink)
                .background(dark ? AnyShapeStyle(.black.opacity(0.35)) : AnyShapeStyle(ServoMapColor.surface),
                            in: RoundedRectangle(cornerRadius: family == .accessoryCircular ? 38 : 22))
            Text(title).font(ServoMapFont.small).foregroundStyle(.white)
        }
    }

    private static func load() async -> PriceEntry {
        let stations = (try? await Nearby.cheapest(.u91)) ?? []
        let history = ((try? await API().trends(state: "nsw")) ?? []).filter { $0.fuel == FuelType.u91.rawValue }
        return PriceEntry(date: .now, fuel: .u91, stations: stations, verdict: TrendMath.verdict(history))
    }
}
