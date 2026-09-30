import MapKit
import SwiftUI

/**
 * A station's page: its price against the area, the four things you do next, where it is, what a
 * tank costs, every fuel it sells, cheaper stations close by, and your own fill-ups there.
 */
struct StationDetail: View {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    let station: Station
    @AppStorage(StorageKey.tankLitres) private var tankLitres = 50
    @State private var logging = false
    /** Set to open directions; DirectionsLauncher picks the app (Settings › Directions). */
    @State private var directionsTo: DirectionsLauncher.Destination?

    var body: some View {
        List {
            Section { header }.paperRow().listSectionSpacing(8)
            // Actions sit straight under the price so they are above the tab bar at half height.
            Section { actions }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listSectionSpacing(8)
            Section { location }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            fillCost
            fuels
            cheaperNearby
            yourFillUps
            // The licence statement and report link (decision 0007), at the foot so the price stays on top.
            if DataSource.forState(station.state)?.hasNotice == true {
                Section { SourceNotice(state: station.state) }.paperRow()
            }
        }
        .paperList()
        // The back button floats over the list; no inline title bar above the station's name.
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(14)
        .sheet(isPresented: $logging) { AddFillUpSheet(station: station) }
        .directionsPrompt($directionsTo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                BrandSeal(family: station.family, size: 22)
                Text(station.family.name).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            }
            Text(station.name).font(ServoMapFont.heading)
            Text(placeLine).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            if let p = price {
                HStack(alignment: .firstTextBaseline) {
                    PriceText(cents: p.price, font: ServoMapFont.priceXl)
                    Spacer()
                    TierText(tier: store.range.tier(p.price))
                }
                .padding(.top, 6)
                if let line = comparisonLine(p.price) {
                    Text(line).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                }
                if station.hasCurrentPrice(store.fuel) {
                    Text("Reported \(p.updatedAt, format: .relative(presentation: .named))")
                        .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                } else {
                    Label("Reported \(p.updatedAt, format: .relative(presentation: .named)). The price may have changed since.",
                          systemImage: "clock.badge.exclamationmark")
                        .font(ServoMapFont.small).foregroundStyle(ServoMapColor.priceMid)
                }
            } else {
                Text("No \(store.fuel.rawValue) price reported here.").font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
            }
            SourceCredit(state: station.state)
        }
        .padding(.vertical, 4)
    }

    private var placeLine: String {
        guard let km = station.distance else { return station.addressLine }
        return "\(station.addressLine) · \(km.formatted(.number.precision(.fractionLength(1)))) km"
    }

    /** "13.9¢ under the local average, 3rd cheapest of 282 nearby." */
    private func comparisonLine(_ cents: Double) -> String? {
        var parts: [String] = []
        if let avg = store.localAverage, abs(avg - cents) >= 0.05 {
            parts.append("\(fmt(abs(avg - cents)))¢ \(cents < avg ? "under" : "over") the local average")
        }
        if let i = store.ranked.firstIndex(of: station) {
            parts.append(i == 0 ? "the cheapest of \(store.ranked.count) nearby" : "\(ordinal(i + 1)) cheapest of \(store.ranked.count) nearby")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ") + "."
    }

    // MARK: Actions

    /** As in Maps: one prominent Directions capsule, then round buttons for the rest. */
    private var actions: some View {
        HStack(spacing: 10) {
            Button { openInMaps() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    // Distance is already on the address line above.
                    Text("Directions")
                }
                .actionFont()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)

            RoundAction(title: "Log fill-up", symbol: "fuelpump") { logging = true }
            RoundAction(title: store.isSaved(station) ? "Saved" : "Save",
                        symbol: store.isSaved(station) ? "bookmark.fill" : "bookmark") { store.toggleSaved(station) }
            ShareLink(item: API.site.appending(path: "station/\(station.id)")) {
                Image(systemName: "square.and.arrow.up").actionFont().frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, 4)
    }

    // MARK: Location

    private var location: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: station.coordinate, latitudinalMeters: 900, longitudinalMeters: 900)),
            interactionModes: []) {
            Annotation(station.name, coordinate: station.coordinate, anchor: .bottom) {
                if let p = price {
                    PriceTag(family: station.family, cents: p.price, tier: store.range.tier(p.price), active: true)
                } else {
                    Circle().fill(ServoMapColor.ink).frame(width: 10, height: 10)
                }
            }
            .annotationTitles(.hidden)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: ServoMapRadius.r3))
        .onTapGesture { openInMaps() }
        .accessibilityLabel("Map of \(station.name). Opens directions.")
    }

    // MARK: Cost

    @ViewBuilder private var fillCost: some View {
        if let p = price {
            Section {
                FillCostCard(litres: tankLitres, rows: costRows(p.price)).paperRow()
            } header: {
                Text("A \(tankLitres) L fill")
            } footer: {
                Text("Tank size is set in Log, under Your car.")
            }
        }
    }

    /** This station, the local average, and the cheapest station nearby when it is another one. */
    private func costRows(_ cents: Double) -> [FillCostCard.Row] {
        var rows = [FillCostCard.Row(label: "Here", cents: cents, isHere: true)]
        if let avg = store.localAverage { rows.append(.init(label: "Local average", cents: avg, isHere: false)) }
        if let best = store.ranked.first, best != station, let bp = best.price(store.fuel), bp.price < cents {
            rows.append(.init(label: best.name, cents: bp.price, isHere: false))
        }
        return rows
    }

    // MARK: Fuels

    private var fuels: some View {
        Section {
            ForEach(FuelType.allCases.filter { station.price($0) != nil }) { fuel in
                FuelRangeRow(fuel: fuel, cents: station.price(fuel)!.price,
                             nearby: store.stations.compactMap { $0.price(fuel)?.price },
                             selected: fuel == store.fuel)
            }
            .paperRow()
        } header: {
            Text("All fuels")
        } footer: {
            Text("Each line runs from the cheapest to the dearest price nearby; the tick is the average.")
        }
    }

    // MARK: Cheaper nearby

    @ViewBuilder private var cheaperNearby: some View {
        let here = CLLocation(latitude: station.lat, longitude: station.lng)
        let rows = store.ranked
            .filter { $0 != station && ($0.price(store.fuel)?.price ?? .infinity) < (price?.price ?? 0) }
            .map { ($0, here.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lng)) / 1000) }
            .filter { $0.1 <= 5 }
            .prefix(3)
        if !rows.isEmpty {
            Section("Cheaper within 5 km") {
                ForEach(Array(rows), id: \.0.id) { other, km in
                    NavigationLink(value: other) {
                        HStack(spacing: 12) {
                            BrandSeal(family: other.family)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(other.name).lineLimit(1)
                                Text("\(km.formatted(.number.precision(.fractionLength(1)))) km from here")
                                    .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                            }
                            Spacer(minLength: 8)
                            if let op = other.price(store.fuel) { PriceText(cents: op.price, font: ServoMapFont.lead) }
                        }
                    }
                }
                .paperRow()
            }
        }
    }

    // MARK: Your fill-ups

    @ViewBuilder private var yourFillUps: some View {
        let here = log.entries.filter { $0.stationID == station.id }
        if let last = here.first {
            Section("Your fill-ups here") {
                Group {
                    LabeledContent("Fill-ups", value: "\(here.count)")
                    LabeledContent("Last", value: last.date.formatted(.dateTime.day().month().year()))
                    LabeledContent("Spent here", value: dollars(here.map(\.cost).reduce(0, +)))
                }
                .paperRow()
            }
        }
    }

    // MARK: Helpers

    private var price: FuelPrice? { station.price(store.fuel) }

    private func openInMaps() {
        directionsTo = DirectionsLauncher.Destination(station)
    }
}

private func fmt(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }
private func dollars(_ v: Double) -> String { v.formatted(.currency(code: "AUD")) }
private func ordinal(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .ordinal
    return f.string(from: n as NSNumber) ?? "\(n)"
}

/** A round glass button with a glyph; the title is its accessibility label. */
private struct RoundAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .actionFont()
                .frame(width: 36, height: 36)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(title)
    }
}
