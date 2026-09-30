import SwiftUI

/**
 * Everything that is yours, behind the avatar on the map (decision 0004). A profile home in the
 * manner of Health's summary: who you are, your car, this month in three figures, your saved
 * stations to swipe through, your log and your alerts. Each block opens its full page.
 */
struct YouScreen: View {
    enum Page: String, CaseIterable, Identifiable, Hashable {
        case saved = "Saved", log = "Log", car = "Car", alerts = "Alerts"
        var id: String { rawValue }
    }

    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Page]
    @AppStorage("carName") private var carName = "My car"
    @AppStorage("tankLitres") private var tankLitres = 50
    @AppStorage("carBody") private var carBody = BodyType.hatch.rawValue
    @AppStorage("carPaint") private var carPaint = CarPaint.silver.rawValue
    @AppStorage("priceAlerts") private var priceAlerts = false
    @AppStorage("alertCycleLow") private var cycleLow = false

    /** Opens on the home, or straight onto `page` (launch arguments and deep links). */
    init(page: Page? = nil) {
        _path = State(initialValue: page.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profile
                    carCard
                    monthStrip
                    savedCarousel
                    logCard
                    alertsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(ServoMapColor.bg)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                destination(page)
                    .navigationTitle(page.rawValue)
                    .navigationBarTitleDisplayMode(.large)
            }
            .navigationDestination(for: Station.self) { StationDetail(station: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }.actionFont()
                }
            }
        }
        .presentationBackground(ServoMapColor.bg)
    }

    @ViewBuilder private func destination(_ page: Page) -> some View {
        switch page {
        case .saved: SavedScreen()
        case .log: LogScreen()
        case .car: CarForm()
        case .alerts: AlertsScreen()
        }
    }

    // MARK: Blocks

    private var profile: some View {
        HStack(spacing: 14) {
            Circle().fill(ServoMapColor.ink)
                .frame(width: 60, height: 60)
                .overlay(Image(systemName: "person.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(ServoMapColor.surface))
            VStack(alignment: .leading, spacing: 3) {
                Text("You").font(ServoMapFont.display(.largeTitle, weight: 600))
                Label("Kept on this iPhone", systemImage: "iphone")
                    .font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .padding(.top, 4)
    }

    private var carCard: some View {
        NavigationLink(value: Page.car) {
            VStack(alignment: .leading, spacing: 10) {
                CarSilhouette(BodyType(rawValue: carBody) ?? .hatch, paint: (CarPaint(rawValue: carPaint) ?? .silver).color)
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                Rectangle().fill(ServoMapColor.line).frame(height: 1)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(carName).font(ServoMapFont.display(.title3, weight: 600))
                        Text("\(store.fuel.rawValue) · \(tankLitres) L tank").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                    }
                    Spacer()
                    if let p = store.inView.first?.price(store.fuel)?.price {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text((p * Double(tankLitres) / 100).formatted(.currency(code: "AUD").precision(.fractionLength(0))))
                                .font(ServoMapFont.display(.title3)).monospacedDigit()
                            Text("a full tank at the cheapest").font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                        }
                    }
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var monthStrip: some View {
        let month = MonthSummary.of(log.entries, month: .now)
        return HStack(spacing: 10) {
            figure(Date.now.formatted(.dateTime.month(.wide)), month.spent.formatted(.currency(code: "AUD").precision(.fractionLength(0))))
            figure("Saved", month.saved.formatted(.currency(code: "AUD")), tint: month.saved > 0 ? ServoMapColor.priceCheap : ServoMapColor.ink)
            figure("Fill-ups", "\(month.count)")
        }
    }

    private func figure(_ title: String, _ value: String, tint: Color = ServoMapColor.ink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            Text(value).font(ServoMapFont.display(.title3)).foregroundStyle(tint).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
    }

    private var savedStations: [Station] {
        store.stations.filter(store.isSaved)
            .sorted { ($0.price(store.fuel)?.price ?? .infinity) < ($1.price(store.fuel)?.price ?? .infinity) }
    }

    private var savedCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            blockHeader("Saved stations", count: store.savedIDs.count, page: .saved)
            if savedStations.isEmpty {
                Text(store.savedIDs.isEmpty
                     ? "Save a station from its page and it shows up here with its price."
                     : "Your saved stations are outside the area on the map.")
                    .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(savedStations.enumerated()), id: \.element.id) { index, station in
                            NavigationLink(value: station) { SavedTile(station: station, fuel: store.fuel, cheapest: index == 0 && savedStations.count > 1) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            blockHeader("Log", count: log.entries.count, page: .log)
            NavigationLink(value: Page.log) {
                VStack(alignment: .leading, spacing: 8) {
                    if let last = log.entries.first {
                        HStack {
                            BrandSeal(family: BrandFamily.resolve(last.brand), size: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Last fill-up · \(last.stationName)").font(ServoMapFont.body).lineLimit(1)
                                Text(last.date.formatted(.relative(presentation: .named))).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                            }
                            Spacer()
                            Text(last.cost.formatted(.currency(code: "AUD"))).font(ServoMapFont.display(.body)).monospacedDigit()
                        }
                        MonthlySpendChart(months: MonthSummary.recent(log.entries, months: 6, now: .now)).frame(height: 110)
                    } else {
                        Text("Log a fill-up from a station's page to track what you spend and save.")
                            .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .buttonStyle(.plain)
        }
    }

    private var alertsCard: some View {
        NavigationLink(value: Page.alerts) {
            HStack(spacing: 12) {
                Image(systemName: priceAlerts || cycleLow ? "bell.badge.fill" : "bell")
                    .font(ServoMapFont.body(.title3, weight: 600)).frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Alerts").font(ServoMapFont.body(.body, weight: 600))
                    Text(alertSummary).font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ServoMapColor.ink3)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var alertSummary: String {
        switch (priceAlerts, cycleLow) {
        case (true, true): "Price drops and low prices"
        case (true, false): "Price drops at saved stations"
        case (false, true): "Low prices near home"
        case (false, false): "Off"
        }
    }

    private func blockHeader(_ title: String, count: Int, page: Page) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(ServoMapFont.display(.title3, weight: 600))
            if count > 0 { Text("\(count)").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3) }
            Spacer()
            NavigationLink("See all", value: page).font(ServoMapFont.body(.footnote, weight: 600))
        }
    }
}

/** A saved station as a small card: its mark, name, price and tier. */
private struct SavedTile: View {
    let station: Station
    let fuel: FuelType
    let cheapest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                BrandSeal(family: station.family, size: 30)
                Spacer()
                if cheapest {
                    Text("Cheapest").font(ServoMapFont.body(.caption2, weight: 700))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ServoMapColor.priceCheapSoft, in: Capsule())
                        .foregroundStyle(ServoMapColor.priceCheap)
                }
            }
            Text(station.name).font(ServoMapFont.body(.footnote, weight: 500)).lineLimit(2, reservesSpace: true)
            if let p = station.price(fuel) {
                PriceText(cents: p.price, font: ServoMapFont.display(.title3))
            }
            Text(station.suburb).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3).lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
        .card(padding: 12)
    }
}

private extension View {
    /** A paper card on the page ground: surface fill, hairline, soft corners. */
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(ServoMapColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(ServoMapColor.lineSubtle))
    }
}

/** The avatar on the map: initials once signed in, a person glyph before. */
struct AvatarButton: View {
    var initials: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let initials {
                    Text(initials).font(ServoMapFont.body(.footnote, weight: 700))
                } else {
                    Image(systemName: "person.fill").font(ServoMapFont.body(.body, weight: 600))
                }
            }
            .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("You: saved stations, log, car and alerts")
    }
}

/** Alert kinds and when they may arrive. Sending starts with decision 0004's phase 4. */
struct AlertsScreen: View {
    @AppStorage("alertCycleLow") private var cycleLow = false
    @AppStorage("quietStart") private var quietStart = 22
    @AppStorage("quietEnd") private var quietEnd = 7

    var body: some View {
        List {
            PriceAlertsSection()
            Section {
                Toggle("Prices near home are low", isOn: $cycleLow).paperRow()
            } footer: {
                Text("When the average near home reaches the bottom of its 60-day range.")
            }
            Section {
                Group {
                    Picker("Quiet from", selection: $quietStart) { ForEach(18..<24, id: \.self) { Text(hour($0)).tag($0) } }
                    Picker("Until", selection: $quietEnd) { ForEach(5..<11, id: \.self) { Text(hour($0)).tag($0) } }
                }
                .paperRow()
            } header: {
                Text("Quiet hours")
            } footer: {
                Text("At most one alert a day, never in quiet hours.")
            }
        }
        .paperList()
    }

    private func hour(_ h: Int) -> String {
        Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)?.formatted(date: .omitted, time: .shortened) ?? "\(h):00"
    }
}
