import SwiftUI

/** A step after the first in the add-a-car flow. */
enum AddCarStep: Hashable {
    /** Which model, for a make. */
    case model(String)
    /** Which years, for a model with more than one generation. */
    case years(CarModel)
    /** Name, fuel and tank; nil when the car is entered by hand. */
    case details(Vehicle?)
}

/**
 * Adding a car (decision 0008): Make → Model → Years → Details, pushed in one navigation stack.
 * Years is skipped when a model has one generation. Editing an existing car opens on Details.
 */
struct AddCarFlow: View {
    enum Start: Equatable {
        case make
        /** "Edit name and tank": Details for the current car. */
        case edit
    }

    let start: Start
    let catalogue: VehicleCatalogue
    /** Steps to open on once the catalogue loads (screenshots): "model", "years" or "details" for `model`. */
    var preset: (step: String, make: String, model: String)?
    @Environment(\.dismiss) private var dismiss
    @State private var path: [AddCarStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: AddCarStep.self) { step in
                    switch step {
                    case .model(let make): AddCarModelStep(make: make, path: $path)
                    case .years(let model): AddCarYearsStep(model: model, path: $path)
                    case .details(let vehicle): AddCarDetailsStep(vehicle: vehicle, editing: false, finish: { dismiss() })
                    }
                }
        }
        .environment(catalogue)
        .presentationBackground(ServoMapColor.bg)
        .task {
            await catalogue.load()
            openPreset()
        }
    }

    @ViewBuilder private var root: some View {
        switch start {
        case .make: AddCarMakeStep(path: $path)
        case .edit: AddCarDetailsStep(vehicle: MyCar.vehicle, editing: true, finish: { dismiss() })
        }
    }

    private func openPreset() {
        guard let preset, preset.step != "make", path.isEmpty, let model = catalogue.make(preset.make)?.models.first(where: { $0.model == preset.model }) else { return }
        var steps: [AddCarStep] = [.model(preset.make)]
        if preset.step != "model", model.asksForYears { steps.append(.years(model)) }
        if preset.step == "details" { steps.append(.details(model.newest)) }
        path = steps
    }
}

/** The caption and Mincho question at the top of each step, with the make's mark when there is one. */
struct AddCarHeader: View {
    let caption: String
    let title: String
    var make: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            if let make { CarMark(make: make, size: 52) }
            VStack(alignment: .leading, spacing: 2) {
                Text(caption).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                Text(title).font(ServoMapFont.display(.title, weight: 500, size: 30))
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/** Four short rules in the navigation bar: how far through the flow this step is. */
struct AddCarProgress: View {
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...4, id: \.self) { i in
                RoundedRectangle(cornerRadius: ServoMapRadius.r1)
                    .fill(i <= step ? ServoMapColor.ink : ServoMapColor.line)
                    .frame(width: 18, height: 4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step) of 4")
    }
}

extension View {
    /** A step's page: paper ground, the progress rules in the bar and no title (the header is the title). */
    func addCarStep(_ step: Int?) -> some View {
        background(ServoMapColor.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let step { ToolbarItem(placement: .principal) { AddCarProgress(step: step) } }
            }
    }
}
