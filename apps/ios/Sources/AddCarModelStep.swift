import SwiftUI

/**
 * Step 2: one row per model of the make, filtered by body. A model with several generations goes
 * on to Years; one with a single generation goes straight to Details.
 */
struct AddCarModelStep: View {
    let make: String
    @Binding var path: [AddCarStep]
    @Environment(VehicleCatalogue.self) private var catalogue
    @AppStorage(MyCar.Key.vehicleID) private var currentID = ""
    @State private var bodyFilter: BodyType?

    var body: some View {
        let models = catalogue.make(make)?.models ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AddCarHeader(caption: "\(make) · 2 of 4", title: "Which model?", make: make)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                if let bodies = catalogue.make(make)?.bodies, bodies.count > 1 {
                    filter(models.count, bodies).padding(.horizontal, 20).padding(.top, 16)
                }
                VStack(spacing: 0) {
                    ForEach(models.filter { bodyFilter == nil || $0.bodyType == bodyFilter }) { model in
                        Button { choose(model) } label: { ModelRow(model: model, current: model.generations.contains { $0.id == currentID }) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.top, 14)
                Text("The year comes next; tank sizes differ between generations.")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                    .padding(.horizontal, 20).padding(.top, 12)
            }
            .padding(.bottom, 32)
        }
        .addCarStep(2)
        .sensoryFeedback(.selection, trigger: bodyFilter)
    }

    private func filter(_ total: Int, _ bodies: [(body: BodyType, count: Int)]) -> some View {
        Picker("Body", selection: $bodyFilter) {
            Text("All \(total)").tag(BodyType?.none)
            ForEach(bodies, id: \.body) { item in
                Text("\(item.body.label) \(item.count)").tag(Optional(item.body))
            }
        }
        .pickerStyle(.segmented)
    }

    private func choose(_ model: CarModel) {
        path.append(model.asksForYears ? .years(model) : .details(model.newest))
    }
}

/** A model: the newest generation's picture, the years and body across generations, tank and fuel. */
private struct ModelRow: View {
    let model: CarModel
    /** The user's current car is this model. */
    let current: Bool

    var body: some View {
        HStack(spacing: 12) {
            CarPicture(path: model.newest.imagePath, make: model.make, subject: "\(model.make) \(model.model)", markSize: 36)
                .frame(width: 112, height: 63)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.model).font(ServoMapFont.display(.body, size: 17))
                Text("\(model.years) · \(model.bodyType.label)").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.tankLabel) L").font(ServoMapFont.display(.body, size: 17)).monospacedDigit()
                Text(model.newest.fuel).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 24)
        .padding(.vertical, 8)
        .background(current ? ServoMapColor.accentSoft : .clear)
        .overlay(alignment: .bottom) { Hairline() }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(model.asksForYears ? "Choose its years next" : "")
    }
}
