import SwiftUI

/**
 * Settings › Map: the fuel the map opens on, how far price tiers compare (with a live mini map),
 * and what the map leaves out.
 */
struct MapSettingsScreen: View {
    @Environment(Store.self) private var store
    @AppStorage(StorageKey.mapFuel) private var mapFuel = ""
    @AppStorage(StorageKey.defaultFuel) private var carFuel = FuelType.u91.rawValue
    @AppStorage(StorageKey.compareKm) private var compareKm = MapPreferences.defaultCompareKm
    @AppStorage(StorageKey.showOldPrices) private var showOld = true
    @AppStorage(StorageKey.hideMembersOnly) private var hideMembers = false

    var body: some View {
        PlainPage {
            fuel
            compare
            PlainGroup(title: "On the map", inset: 0) {
                PlainToggleRow(title: "Show prices older than a week", subtitle: "As hollow dots; never ranked as cheapest", isOn: $showOld) {
                    OldPricesPreview()
                }
                PlainToggleRow(title: "Hide members-only stations", subtitle: "Costco and other warehouse clubs", isOn: $hideMembers) {
                    BrandSeal(family: BrandFamily.resolve("Costco"), size: 18).frame(width: 28, height: 22)
                }
            }
        }
        .onChange(of: hideMembers) { store.filters.hideMembersOnly = hideMembers }
        .onChange(of: compareKm) { store.compareKm = compareKm }
    }

    private var fuel: some View {
        PlainGroup(title: "Fuel", footer: "The map opens on this fuel. It follows your car unless you pick one here.") {
            Picker("Fuel", selection: fuelChoice) {
                ForEach(FuelType.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, ServoMapSpace.x2)
            .sensoryFeedback(.selection, trigger: mapFuel)
        }
    }

    /** The picked fuel, or the car's while none is picked. Picking also switches the map now. */
    private var fuelChoice: Binding<FuelType> {
        Binding {
            FuelType(rawValue: mapFuel) ?? FuelType(rawValue: carFuel) ?? .u91
        } set: { fuel in
            mapFuel = fuel.rawValue
            store.fuel = fuel
        }
    }

    private var compare: some View {
        let count = CompareRadius.inside(store.stations, fuel: store.fuel, around: store.compareCentre, km: compareKm).count
        return VStack(alignment: .leading, spacing: ServoMapSpace.x3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compare within \(compareKm) km").font(ServoMapFont.display(.title3, weight: 600))
                    .contentTransition(.numericText())
                    .accessibilityAddTraits(.isHeader)
                Text("\(count) stations with \(store.fuel.rawValue) around \(store.located ? "you" : store.placeName)")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            CompareRadiusMap(km: compareKm)
            Picker("Compare within", selection: $compareKm.animation(ServoMapMotion.standard)) {
                ForEach(MapPreferences.compareChoices, id: \.self) { Text("\($0) km").tag($0) }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: compareKm)
            legend
        }
        .padding(.top, ServoMapList.groupGap)
    }

    private var legend: some View {
        HStack(spacing: ServoMapSpace.x3 + 2) {
            ForEach([PriceTier.cheap, .fair, .pricey], id: \.self) { tier in
                HStack(spacing: 5) {
                    Circle().fill(tier.color).frame(width: 8, height: 8)
                    Text(tier.rawValue)
                }
            }
            Spacer()
            Text("tiers within \(compareKm) km").foregroundStyle(ServoMapColor.ink3)
        }
        .font(ServoMapFont.small)
        .foregroundStyle(ServoMapColor.ink2)
        .accessibilityElement(children: .combine)
    }
}

/** A current price's filled dot beside an old price's hollow ring, as the map draws them. */
private struct OldPricesPreview: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(ServoMapColor.priceCheap).frame(width: MapDots.size, height: MapDots.size)
            Circle().stroke(ServoMapColor.ink3, lineWidth: 1.5)
                .background(Circle().fill(ServoMapColor.surface))
                .frame(width: MapDots.size, height: MapDots.size)
        }
        .frame(width: 28, height: 22)
        .background(ServoMapColor.mapLand, in: RoundedRectangle(cornerRadius: ServoMapRadius.r3))
        .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r3).strokeBorder(ServoMapColor.line, lineWidth: ServoMapList.hairline))
        .accessibilityHidden(true)
    }
}
