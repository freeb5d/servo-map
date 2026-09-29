import AppIntents
import SwiftUI

/** "Cheapest fuel with ServoMap": answers with the cheapest station nearby and shows it as a snippet. */
struct CheapestFuelIntent: AppIntent {
    static let title: LocalizedStringResource = "Cheapest fuel nearby"
    static let description = IntentDescription("Finds the cheapest station for a fuel near Sydney CBD.")

    @Parameter(title: "Fuel", default: .u91)
    var fuel: FuelType

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let stations = try await Nearby.cheapest(fuel)
        guard let best = stations.first, let price = best.price(fuel)?.price else {
            return .result(dialog: "I couldn’t find \(fuel.rawValue) prices near \(Nearby.place) right now.", view: EmptyView().eraseToAny())
        }
        let cents = price.formatted(.number.precision(.fractionLength(1)))
        return .result(
            dialog: "\(best.name) in \(best.suburb) has \(fuel.rawValue) at \(cents) cents a litre.",
            view: CheapestSnippet(stations: stations, fuel: fuel).eraseToAny()
        )
    }
}

struct ServoMapShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheapestFuelIntent(),
            phrases: [
                "Cheapest fuel with \(.applicationName)",
                "Find cheap \(\.$fuel) with \(.applicationName)",
            ],
            shortTitle: "Cheapest fuel",
            systemImageName: "fuelpump"
        )
    }
}

private struct CheapestSnippet: View {
    let stations: [Station]
    let fuel: FuelType

    var body: some View {
        VStack(spacing: 10) {
            ForEach(stations) { station in
                HStack(spacing: 10) {
                    BrandSeal(family: station.family)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(station.name).font(ServoMapFont.body).lineLimit(1)
                        Text(station.suburb).font(ServoMapFont.small).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let p = station.price(fuel) { PriceText(cents: p.price) }
                }
            }
        }
        .padding()
    }
}

private extension View {
    func eraseToAny() -> AnyView { AnyView(self) }
}
