import SwiftUI

/**
 * Step 4: the car's name, the fuel bought for it and its tank, with the catalogue's size shown and
 * overridable. Also "Edit name and tank" for the current car, and the page for a car entered by hand.
 */
struct AddCarDetailsStep: View {
    /** The catalogue generation; nil for a car entered by hand. */
    let vehicle: Vehicle?
    let editing: Bool
    let finish: () -> Void
    @Environment(Store.self) private var store
    @State private var name: String
    @State private var fuel: FuelType
    @State private var tank: Int
    @State private var bodyType: BodyType
    @State private var saves = 0

    init(vehicle: Vehicle?, editing: Bool, finish: @escaping () -> Void) {
        self.vehicle = vehicle
        self.editing = editing
        self.finish = finish
        let d = UserDefaults.standard
        let storedName = d.string(forKey: MyCar.Key.name) ?? MyCar.defaultName
        let storedFuel = FuelType(rawValue: d.string(forKey: MyCar.Key.fuel) ?? "")
        let storedTank = d.object(forKey: MyCar.Key.tank) as? Int
        let storedBody = BodyType(rawValue: d.string(forKey: MyCar.Key.body) ?? "")
        if editing {
            _name = State(initialValue: vehicle == nil ? (storedName == MyCar.defaultName ? "" : storedName) : (MyCar.nickname(storedName, vehicle: vehicle) ?? ""))
            _fuel = State(initialValue: storedFuel ?? vehicle?.fuelType ?? .u91)
            _tank = State(initialValue: storedTank ?? vehicle?.tankLitres ?? 50)
            _bodyType = State(initialValue: storedBody ?? vehicle?.bodyType ?? .hatch)
        } else {
            _name = State(initialValue: "")
            _fuel = State(initialValue: vehicle?.fuelType ?? storedFuel ?? .u91)
            _tank = State(initialValue: vehicle?.tankLitres ?? 50)
            _bodyType = State(initialValue: vehicle?.bodyType ?? .hatch)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AddCarHeader(caption: caption, title: title).padding(.top, 4)
                CarPicture(path: vehicle?.imagePath ?? VehicleImage.path(id: nil, body: bodyType.rawValue),
                           make: vehicle?.make, subject: vehicle?.name ?? bodyType.label, labelled: true)
                    .frame(height: 186)
                    .padding(.top, 12)
                nameField.padding(.top, 22)
                fuelChoice.padding(.top, 22)
                if vehicle == nil { bodyChoice.padding(.top, 22) }
                tankSize.padding(.top, 22)
                Button(action: save) {
                    Text(editing ? "Save" : "Save car").frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .actionFont()
                .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .addCarStep(editing ? nil : 4)
        .toolbar {
            if editing {
                ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark", action: finish) }
            }
        }
        .sensoryFeedback(.selection, trigger: fuel)
        .sensoryFeedback(.selection, trigger: bodyType)
        .sensoryFeedback(.success, trigger: saves)
    }

    private var caption: String {
        let who = vehicle?.make ?? "Add a car"
        return editing ? (vehicle?.make ?? "Your car") : "\(who) · 4 of 4"
    }

    private var title: String {
        guard let vehicle else { return "Your car" }
        return "\(vehicle.model), \(vehicle.yearRange)"
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Name").font(ServoMapFont.display(.headline, size: 18))
                Text("optional").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            TextField(vehicle?.name ?? MyCar.defaultName, text: $name)
                .font(ServoMapFont.body(.callout))
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .background(ServoMapColor.surface, in: RoundedRectangle(cornerRadius: ServoMapRadius.r3))
                .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r3).strokeBorder(ServoMapColor.line, lineWidth: 0.5))
        }
    }

    private var fuelChoice: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Fuel you buy").font(ServoMapFont.display(.headline, size: 18))
                Spacer(minLength: 8)
                if let vehicle, let recommended = vehicle.fuelType {
                    Text("\(vehicle.make) recommends \(recommended.rawValue)").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                }
            }
            Grid(horizontalSpacing: 6) {
                GridRow {
                    ForEach(FuelType.allCases) { option in
                        fuelButton(option)
                    }
                }
            }
        }
    }

    @ViewBuilder private func fuelButton(_ option: FuelType) -> some View {
        let label = Text(option.rawValue).font(ServoMapFont.body(.subheadline, weight: option == fuel ? 600 : 400))
            .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: .infinity, minHeight: 28)
        if option == fuel {
            Button { fuel = option } label: { label }.buttonStyle(.glassProminent).buttonBorderShape(.capsule)
                .accessibilityAddTraits(.isSelected)
        } else {
            Button { fuel = option } label: { label }.buttonStyle(.glass).buttonBorderShape(.capsule)
        }
    }

    /** A car entered by hand picks its body, which chooses its stand-in picture. */
    private var bodyChoice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Body").font(ServoMapFont.display(.headline, size: 18))
            Picker("Body", selection: $bodyType) {
                ForEach(BodyType.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var tankSize: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tank size").font(ServoMapFont.display(.headline, size: 18))
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(tank) L").font(ServoMapFont.display(.largeTitle, size: 34)).monospacedDigit()
                        .contentTransition(.numericText(value: Double(tank)))
                    Text(tankNote).font(ServoMapFont.small).foregroundStyle(changed ? ServoMapColor.priceMid : ServoMapColor.ink3)
                }
                Spacer(minLength: 8)
                Stepper("Tank size", value: $tank, in: 20...200).labelsHidden()
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) { Hairline() }
            .accessibilityElement(children: .combine)
            if let catalogue = vehicle?.tankLitres, changed {
                Button("Use the catalogue’s \(catalogue) L") { tank = catalogue }
                    .font(ServoMapFont.body(.footnote, weight: 600))
                    .underline()
                    .buttonStyle(.plain)
            }
        }
        .animation(ServoMapMotion.standard, value: tank)
    }

    private var changed: Bool { vehicle.map { $0.tankLitres != tank } ?? false }

    private var tankNote: String {
        guard let vehicle else { return "Your value" }
        if changed { return "Your value · catalogue says \(vehicle.tankLitres) L" }
        return vehicle.sourceHost.map { "From the catalogue, \($0)" } ?? "From the catalogue"
    }

    private func save() {
        MyCar.save(vehicle: vehicle, name: name, body: bodyType, fuel: fuel, tankLitres: tank, store: store)
        saves += 1
        finish()
    }
}
