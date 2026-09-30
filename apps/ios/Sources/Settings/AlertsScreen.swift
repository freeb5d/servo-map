import SwiftUI

/**
 * Settings › Alerts (decision 0004): the two rules, each with a small sketch of what it watches,
 * where home is, and quiet hours on a 24-hour strip. The switches and hours are the keys
 * AccountSync pushes to the account, so the server's alert job reads the same settings.
 */
struct AlertsScreen: View {
    @Environment(Store.self) private var store
    @Environment(AccountStore.self) private var account
    @AppStorage(StorageKey.priceAlerts) private var priceDrop = false
    @AppStorage(StorageKey.alertCycleLow) private var cycleLow = false
    @AppStorage(StorageKey.quietStart) private var quietStart = 22
    @AppStorage(StorageKey.quietEnd) private var quietEnd = 7
    @AppStorage(StorageKey.homeLat) private var homeLat: Double?
    @AppStorage(StorageKey.homeLng) private var homeLng: Double?
    @AppStorage(StorageKey.tankLitres) private var tankLitres = 50
    @State private var denied = false
    @State private var editingQuiet = false
    @State private var confirmHome = false
    @State private var location = Location()

    var body: some View {
        PlainPage(intro: "At most one a day, and never during quiet hours.") {
            PlainGroup(title: "Tell me when",
                       footer: denied ? "Notifications are off for ServoMap. Turn them on in the Settings app to get alerts." : nil,
                       inset: 0) {
                PlainToggleRow(title: "A saved station drops", subtitle: "By 3¢ or more", isOn: $priceDrop) { PriceDropSketch() }
                PlainToggleRow(title: "Prices are low near home", subtitle: "Bottom of the 60-day range, within 5 km", isOn: $cycleLow) { CycleLowSketch() }
            }
            PlainGroup(title: "Where and when", inset: 0) {
                Button { confirmHome = true } label: {
                    PlainRow(title: "Home", subtitle: "Kept to about 1 km", value: homeValue)
                }
                .buttonStyle(.plainRow)
                quietHours
            }
            example
        }
        .onChange(of: priceDrop) { if priceDrop { askPermission { priceDrop = false } } }
        .onChange(of: cycleLow) { if cycleLow { askPermission { cycleLow = false } } }
        .confirmationDialog("Set home to where you are now?", isPresented: $confirmHome, titleVisibility: .visible) {
            Button("Use my location") { Task { await setHome() } }
        } message: {
            Text("Low-price alerts look within 5 km of home. It is stored to about 1 km.")
        }
    }

    // MARK: Rows

    private var quietHours: some View {
        VStack(alignment: .leading, spacing: ServoMapSpace.x2) {
            Button { withAnimation(ServoMapMotion.standard) { editingQuiet.toggle() } } label: {
                PlainRow(title: "Quiet hours", value: QuietHours.label(start: quietStart, end: quietEnd), chevron: false)
            }
            .buttonStyle(.plainRow)
            .accessibilityHint(editingQuiet ? "Hides the hours" : "Shows the hours to change them")
            QuietHoursStrip(start: quietStart, end: quietEnd)
            if editingQuiet {
                PlainHairline()
                Picker("Quiet from", selection: $quietStart) { ForEach(18..<24, id: \.self) { Text(QuietHours.hour($0)).tag($0) } }
                    .frame(minHeight: ServoMapList.rowHeight)
                PlainHairline()
                Picker("Until", selection: $quietEnd) { ForEach(5..<11, id: \.self) { Text(QuietHours.hour($0)).tag($0) } }
                    .frame(minHeight: ServoMapList.rowHeight)
            }
        }
        .font(ServoMapFont.lead)
        .padding(.bottom, ServoMapSpace.x2)
        .sensoryFeedback(.selection, trigger: quietStart * 100 + quietEnd)
    }

    /**
     * What a price-drop alert says, worded as the server's job words it (scripts/send-alerts.ts),
     * with the cheapest station on the map standing in.
     */
    @ViewBuilder private var example: some View {
        if let station = store.cheapestInView, let price = station.price(store.fuel)?.price {
            let drop = 4.0
            VStack(alignment: .leading, spacing: ServoMapSpace.x2) {
                Text("Example").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "fuelpump")
                        .font(ServoMapFont.body(.body, weight: 500))
                        .frame(width: 38, height: 38)
                        .background(ServoMapColor.bg, in: RoundedRectangle(cornerRadius: ServoMapRadius.r3))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(station.name) dropped \(cents(drop))¢").font(ServoMapFont.body(.subheadline, weight: 600)).lineLimit(1)
                            Spacer(minLength: ServoMapSpace.x1)
                            Text("now").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                        }
                        Text("\(store.fuel.rawValue) is \(cents(price)) now, so a full tank costs \(dollars(drop * Double(tankLitres) / 100)) less than before.")
                            .font(ServoMapFont.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(ServoMapSpace.x3)
                // A notification banner is system chrome, so it takes the system's glass and shape.
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
            }
            .padding(.top, ServoMapList.groupGap)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Actions

    private var homeValue: String {
        guard let lat = homeLat, let lng = homeLng else { return "Not set" }
        // Named after the nearest station's suburb, so no lookup leaves the device.
        let nearest = store.stations.min { Store.distanceKm((lat, lng), ($0.lat, $0.lng)) < Store.distanceKm((lat, lng), ($1.lat, $1.lng)) }
        guard let nearest, Store.distanceKm((lat, lng), (nearest.lat, nearest.lng)) <= 3 else { return "Set" }
        return nearest.suburb
    }

    private func setHome() async {
        guard let here = await location.locate() else { return }
        AlertPrefs.setHome(lat: here.latitude, lng: here.longitude)
        await account.pushAlerts()
    }

    /** Turning a rule on asks once for notifications; refused, the switch goes back off. */
    private func askPermission(else turnOff: @escaping () -> Void) {
        Task {
            let allowed = await PriceAlerts.enable()
            denied = !allowed
            if !allowed { turnOff() }
        }
    }

    private func cents(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(1))) }
    private func dollars(_ v: Double) -> String { v.formatted(.currency(code: "AUD")) }
}
