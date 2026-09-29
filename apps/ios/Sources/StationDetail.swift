import MapKit
import SwiftUI

struct StationDetail: View {
    @Environment(Store.self) private var store
    let station: Station
    @AppStorage("tankLitres") private var tankLitres = 50
    @State private var logging = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        BrandSeal(family: station.family)
                        Text(station.family.name).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                    }
                    Text(station.name).font(ServoMapFont.heading)
                    Text(station.addressLine).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                    if let p = station.price(store.fuel) {
                        HStack(alignment: .firstTextBaseline) {
                            PriceText(cents: p.price, font: ServoMapFont.priceXl)
                            Spacer()
                            TierText(tier: store.range.tier(p.price))
                        }
                        .padding(.top, 4)
                        Text("Reported \(p.updatedAt, format: .relative(presentation: .named))")
                            .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                    }
                }
                .paperRow()
            }

            if let p = station.price(store.fuel), let avg = store.localAverage {
                Section {
                    LabeledContent("\(tankLitres) L here", value: (p.price * Double(tankLitres) / 100).formatted(.currency(code: "AUD")))
                    LabeledContent("Against the local average", value: ((avg - p.price) * Double(tankLitres) / 100).formatted(.currency(code: "AUD")))
                }
                .paperRow()
            }

            Section("All fuels") {
                ForEach(station.prices, id: \.fuel) { fp in
                    LabeledContent(fp.fuel) { PriceText(cents: fp.price, font: ServoMapFont.lead) }
                        .fontWeight(fp.fuel == store.fuel.rawValue ? .semibold : .regular)
                }
                .paperRow()
            }

            Section {
                HStack(spacing: 10) {
                    Button("Directions", systemImage: "arrow.triangle.turn.up.right.diamond") { openInMaps() }
                        .buttonStyle(.glassProminent)
                        .frame(maxWidth: .infinity)
                    Button("Log fill-up", systemImage: "plus") { logging = true }
                        .buttonStyle(.glass)
                }
                .listRowBackground(Color.clear)
            }
        }
        .paperList()
        .sheet(isPresented: $logging) { AddFillUpSheet(station: station) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(store.isSaved(station) ? "Saved" : "Save", systemImage: store.isSaved(station) ? "bookmark.fill" : "bookmark") {
                    store.toggleSaved(station)
                }
                ShareLink(item: URL(string: "https://servo-map.com/station/\(station.id)")!)
            }
        }
    }

    private func openInMaps() {
        let item = MKMapItem(location: CLLocation(latitude: station.lat, longitude: station.lng), address: nil)
        item.name = station.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
