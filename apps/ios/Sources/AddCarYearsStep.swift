import SwiftUI

/** Step 3: one card per generation, named by its year range, with its picture, tank and fuel. */
struct AddCarYearsStep: View {
    let model: CarModel
    @Binding var path: [AddCarStep]
    @AppStorage(MyCar.Key.vehicleID) private var currentID = ""
    @State private var chosen: Vehicle?

    var body: some View {
        let picked = chosen ?? model.generations.first { $0.id == currentID } ?? model.newest
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AddCarHeader(caption: "\(model.make) \(model.model) · 3 of 4", title: "Which years?")
                    .padding(.top, 4)
                VStack(spacing: 12) {
                    ForEach(model.generations) { generation in
                        GenerationCard(vehicle: generation, selected: generation == picked) { chosen = generation }
                    }
                }
                .padding(.top, 22)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Years")
                Button { path.append(.details(picked)) } label: {
                    Text("Continue with \(picked.yearRange)").frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .actionFont()
                .padding(.top, 28)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .addCarStep(3)
        .sensoryFeedback(.selection, trigger: chosen)
    }
}

/** A generation as a choice: its year range in Mincho, a radio mark, the picture and its figures. */
private struct GenerationCard: View {
    let vehicle: Vehicle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(vehicle.yearRange).font(ServoMapFont.display(.title2, size: 24)).monospacedDigit()
                    Spacer()
                    Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                        .font(ServoMapFont.body(.title3))
                        .foregroundStyle(selected ? ServoMapColor.ink : ServoMapColor.line)
                }
                CarPicture(path: vehicle.imagePath, make: vehicle.make, subject: "\(vehicle.name), \(vehicle.yearRange)")
                    .frame(height: 158)
                    .frame(maxWidth: 280)
                    .frame(maxWidth: .infinity)
                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(vehicle.tankLitres) L").font(ServoMapFont.display(.body, size: 17)).monospacedDigit()
                            .foregroundStyle(ServoMapColor.ink)
                        Text("tank")
                    }
                    Text(vehicle.fuel)
                    Text(vehicle.bodyType.label)
                }
                .font(ServoMapFont.body)
                .foregroundStyle(ServoMapColor.ink2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background(selected ? ServoMapColor.surface : .clear, in: shape)
            .overlay(shape.strokeBorder(selected ? ServoMapColor.ink : ServoMapColor.line, lineWidth: selected ? 1.5 : 0.5))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: ServoMapRadius.r3) }
}
