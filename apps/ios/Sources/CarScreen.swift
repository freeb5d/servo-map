import SwiftUI

/** Paint colours for the car drawing; everyday car colours, not brand or tier colours. */
enum CarPaint: String, CaseIterable, Identifiable {
    case white, silver, grey, black, red, blue, green, bronze
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .white: Color(brand: 0xEDEBE6)
        case .silver: Color(brand: 0xB8B8B4)
        case .grey: Color(brand: 0x6E6E6A)
        case .black: Color(brand: 0x2B2B2B)
        case .red: Color(brand: 0xA8322D)
        case .blue: Color(brand: 0x2F4F7F)
        case .green: Color(brand: 0x3F5B4A)
        case .bronze: Color(brand: 0x8A6A48)
        }
    }
}

/**
 * My car: a drawing of it, the model picked from the shared catalogue (which fills in the tank
 * size and fuel), the tank size overridable, and a paint colour.
 */
struct CarForm: View {
    @Environment(Store.self) private var store
    @AppStorage("carName") private var name = "My car"
    @AppStorage("carVehicleID") private var vehicleID = ""
    @AppStorage("carBody") private var carBody = BodyType.hatch.rawValue
    @AppStorage("carPaint") private var paint = CarPaint.silver.rawValue
    @AppStorage("tankLitres") private var tankLitres = 50
    @AppStorage("catalogueTankLitres") private var catalogueTank = 0
    @AppStorage("defaultFuel") private var defaultFuel = FuelType.u91.rawValue
    @State private var picking = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    CarSilhouette(BodyType(rawValue: carBody) ?? .hatch, paint: (CarPaint(rawValue: paint) ?? .silver).color)
                        .frame(maxWidth: 280)
                        .animation(ServoMapMotion.standard, value: paint)
                    Text(name).font(ServoMapFont.display(.title2, weight: 600))
                    HStack(spacing: 10) {
                        ForEach(CarPaint.allCases) { p in
                            Button { paint = p.rawValue } label: {
                                Circle().fill(p.color)
                                    .overlay(Circle().strokeBorder(ServoMapColor.line))
                                    .overlay(Circle().inset(by: -4).stroke(ServoMapColor.ink, lineWidth: paint == p.rawValue ? 2 : 0))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(p.rawValue.capitalized)
                            .accessibilityAddTraits(paint == p.rawValue ? .isSelected : [])
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .paperRow()
            }

            Section {
                Button { picking = true } label: {
                    HStack {
                        Text("Model").foregroundStyle(ServoMapColor.ink)
                        Spacer()
                        Text(vehicleID.isEmpty ? "Choose" : name).foregroundStyle(ServoMapColor.ink3).lineLimit(1)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ServoMapColor.ink3)
                    }
                }
                .paperRow()
                Picker("Fuel", selection: $defaultFuel) {
                    ForEach(FuelType.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                .paperRow()
                Stepper(value: $tankLitres, in: 20...200) {
                    HStack(spacing: 6) {
                        Text("Tank")
                        Text("\(tankLitres) L").monospacedDigit().foregroundStyle(ServoMapColor.ink2)
                        if catalogueTank > 0 {
                            Text(tankLitres == catalogueTank ? "catalogue" : "your value")
                                .font(ServoMapFont.label)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(ServoMapColor.wash, in: Capsule())
                                .foregroundStyle(ServoMapColor.ink3)
                        }
                    }
                }
                .paperRow()
                if catalogueTank > 0 && tankLitres != catalogueTank {
                    Button("Use the catalogue's \(catalogueTank) L") { tankLitres = catalogueTank }.paperRow()
                }
            } footer: {
                Text("ServoMap opens on this fuel and prices a full tank at this size.")
            }

            Section {
                TextField("Name", text: $name).paperRow()
            } header: {
                Text("Name")
            }
        }
        .paperList()
        .onChange(of: defaultFuel) { if let f = FuelType(rawValue: defaultFuel) { store.fuel = f } }
        .sheet(isPresented: $picking) { VehiclePicker(onPick: choose) }
    }

    /** Takes a catalogue model: its name, drawing, fuel and tank size (which stays editable). */
    private func choose(_ v: Vehicle) {
        vehicleID = v.id
        name = v.name
        carBody = v.body
        tankLitres = v.tankLitres
        catalogueTank = v.tankLitres
        if let f = v.fuelType { defaultFuel = f.rawValue }
    }
}

/** Search the catalogue as you type, or browse it by make. */
struct VehiclePicker: View {
    let onPick: (Vehicle) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Vehicle] = []
    @State private var makes: [String] = []
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section("Makes") {
                        ForEach(makes, id: \.self) { make in
                            Button { query = make } label: {
                                HStack {
                                    Text(make).foregroundStyle(ServoMapColor.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ServoMapColor.ink3)
                                }
                            }
                            .paperRow()
                        }
                    }
                } else {
                    Section {
                        ForEach(results) { v in
                            Button { onPick(v); dismiss() } label: { VehicleRow(vehicle: v) }.paperRow()
                        }
                    } footer: {
                        Text("Not listed? Close this and enter the tank size yourself.")
                    }
                }
            }
            .paperList()
            .overlay {
                if failed { ContentUnavailableView("Couldn't load the catalogue", systemImage: "wifi.exclamationmark", description: Text("Check your connection and try again.")) }
                else if !query.isEmpty && results.isEmpty { ContentUnavailableView.search(text: query) }
            }
            .navigationTitle("Choose your car")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Make, model or year")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.actionFont() }
            }
            .task { await loadMakes() }
            .task(id: query) { await search() }
        }
        .presentationBackground(ServoMapColor.bg)
    }

    private func loadMakes() async {
        do { makes = try await API().vehicleMakes(); failed = false } catch { failed = true }
    }

    private func search() async {
        guard !query.isEmpty else { results = []; return }
        // Debounce: wait for a pause in typing before asking the server.
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        do { results = try await API().vehicles(query); failed = false } catch { failed = true }
    }
}

private struct VehicleRow: View {
    let vehicle: Vehicle
    var body: some View {
        HStack(spacing: 12) {
            CarSilhouette(vehicle.bodyType).frame(width: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.name).foregroundStyle(ServoMapColor.ink)
                Text("\(vehicle.years) · \(vehicle.bodyType.label)").font(ServoMapFont.small).foregroundStyle(ServoMapColor.ink3)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vehicle.tankLitres) L").font(ServoMapFont.display(.body)).monospacedDigit().foregroundStyle(ServoMapColor.ink)
                Text(vehicle.fuel).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
