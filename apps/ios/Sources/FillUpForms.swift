import SwiftUI

/** Records a fill-up. From a station page the station and price are filled in; the user adds litres. */
struct AddFillUpSheet: View {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(\.dismiss) private var dismiss
    @AppStorage("tankLitres") private var tankLitres = 50
    @State private var stationID: String
    @State private var litres: Double = 0
    @State private var price: Double = 0
    @State private var date = Date.now

    init(station: Station?) {
        _stationID = State(initialValue: station?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Station") {
                    Picker("Station", selection: $stationID) {
                        Text("Choose").tag("")
                        ForEach(choices) { s in Text(s.name).tag(s.id) }
                    }
                    .paperRow()
                }
                Section {
                    LabeledContent("Litres") {
                        TextField("Litres", value: $litres, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    .paperRow()
                    LabeledContent("Price, ¢/L") {
                        TextField("Price", value: $price, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    .paperRow()
                    DatePicker("When", selection: $date, in: ...Date.now).paperRow()
                } footer: {
                    if litres > 0, price > 0 {
                        Text("\((litres * price / 100).formatted(.currency(code: "AUD"))) at the pump.")
                    }
                }
            }
            .paperList()
            .navigationTitle("Log a fill-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.actionFont() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.buttonStyle(.glassProminent).actionFont().disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: stationID) { prefill() }
        }
    }

    /** The station passed in, then the cheapest nearby, so the usual pick is near the top. */
    private var choices: [Station] {
        var list = Array(store.ranked.prefix(20))
        if let current = store.stations.first(where: { $0.id == stationID }), !list.contains(current) { list.insert(current, at: 0) }
        return list
    }

    private var selectedStation: Station? { store.stations.first { $0.id == stationID } }
    private var canSave: Bool { selectedStation != nil && litres > 0 && price > 0 }

    private func prefill() {
        if litres == 0 { litres = Double(tankLitres) }
        if let p = selectedStation?.price(store.fuel)?.price { price = p }
    }

    private func save() {
        guard let s = selectedStation else { return }
        log.add(FillUp(date: date, stationID: s.id, stationName: s.name, brand: s.brand, fuel: store.fuel,
                       litres: litres, centsPerLitre: price, areaAverage: store.localAverage))
        dismiss()
    }
}

/** The car profile: a name, the fuel it takes and the tank size used for fill-up costs. */
struct CarForm: View {
    @Environment(Store.self) private var store
    @AppStorage("carName") private var carName = "My car"
    @AppStorage("tankLitres") private var tankLitres = 50
    @AppStorage("defaultFuel") private var defaultFuel = FuelType.u91.rawValue

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $carName).paperRow()
                Picker("Fuel", selection: $defaultFuel) {
                    ForEach(FuelType.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .paperRow()
                Stepper("Tank  \(tankLitres) L", value: $tankLitres, in: 20...150, step: 1).paperRow()
            } footer: {
                Text("ServoMap opens on this fuel and prices a full tank at this size.")
            }
        }
        .paperList()
        .onChange(of: defaultFuel) { if let f = FuelType(rawValue: defaultFuel) { store.fuel = f } }
    }
}
