import SwiftUI

/** Step 1: search the catalogue, or pick a make from the most common and then the rest, A to Z. */
struct AddCarMakeStep: View {
    @Binding var path: [AddCarStep]
    @Environment(VehicleCatalogue.self) private var catalogue
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Vehicle] = []
    @State private var searchFailed = false
    @State private var searching = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AddCarHeader(caption: "Add a car · 1 of 4", title: "Who makes it?")
                    .padding(.top, 4)
                searchField.padding(.top, 16)
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    browse
                } else {
                    searchResults
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.immediately)
        .addCarStep(1)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
        }
        .task(id: query) { await search() }
        .sensoryFeedback(.selection, trigger: path)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(ServoMapColor.ink3)
            TextField("Make, model or year, e.g. CX-5 2019", text: $query)
                .font(ServoMapFont.body(.callout))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: Browse

    @ViewBuilder private var browse: some View {
        switch catalogue.phase {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
        case .failed:
            ContentUnavailableView {
                Label("Couldn't load the catalogue", systemImage: "wifi.exclamationmark")
            } description: {
                Text("Check your connection and try again.")
            } actions: {
                Button("Try again") { Task { await catalogue.load() } }.buttonStyle(.glass)
            }
            .padding(.top, 24)
        case .loaded:
            let common = CarMake.mostCommon(catalogue.makes)
            let names = Set(common.map(\.name))
            commonGrid(common).padding(.top, 22)
            allMakes(catalogue.makes.filter { !names.contains($0.name) }).padding(.top, 22)
            byHand.padding(.top, 16)
        }
    }

    private func commonGrid(_ makes: [CarMake]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading(title: "Most common")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(makes) { make in
                    Button { path.append(.model(make.name)) } label: {
                        VStack(spacing: 8) {
                            CarMark(make: make.name, size: 52)
                            Text(make.name).font(ServoMapFont.body(.callout)).lineLimit(1).minimumScaleFactor(0.8)
                            Text(models(make)).font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func allMakes(_ makes: [CarMake]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "All makes").padding(.bottom, 6)
            ForEach(makes) { make in
                Button { path.append(.model(make.name)) } label: {
                    HStack(spacing: 12) {
                        CarMark(make: make.name, size: 32)
                        Text(make.name).font(ServoMapFont.lead)
                        Spacer(minLength: 8)
                        Text("\(make.models.count)").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                        Image(systemName: "chevron.right").font(ServoMapFont.body(.footnote, weight: 600)).foregroundStyle(ServoMapColor.ink3)
                    }
                    .padding(.vertical, 10)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Hairline() }
                .accessibilityLabel("\(make.name), \(models(make))")
            }
        }
    }

    /** Cars outside the catalogue: straight to Details with the tank typed in. */
    private var byHand: some View {
        Button { path.append(.details(nil)) } label: {
            Text("Not listed? Enter your car yourself").font(ServoMapFont.body(.footnote, weight: 600))
                .underline(color: ServoMapColor.line)
        }
        .buttonStyle(.plain)
    }

    private func models(_ make: CarMake) -> String {
        "\(make.models.count) model\(make.models.count == 1 ? "" : "s")"
    }

    // MARK: Search

    @ViewBuilder private var searchResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(results) { vehicle in
                Button { path.append(.details(vehicle)) } label: { GenerationRow(vehicle: vehicle) }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Hairline() }
            }
        }
        .padding(.top, 14)
        .overlay {
            if searchFailed {
                ContentUnavailableView("Couldn't search the catalogue", systemImage: "wifi.exclamationmark",
                                       description: Text("Check your connection and try again."))
            } else if results.isEmpty && !searching {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { results = []; return }
        searching = true
        defer { searching = false }
        // Wait for a pause in typing before asking the server.
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        do {
            results = try await API().vehicles(q)
            searchFailed = false
        } catch {
            searchFailed = !Task.isCancelled
        }
    }
}

/** A generation found by search: its picture, name and years, tank and fuel. */
private struct GenerationRow: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 12) {
            CarPicture(path: vehicle.imagePath, make: vehicle.make, subject: vehicle.name, markSize: 32)
                .frame(width: 96, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(vehicle.name).font(ServoMapFont.display(.body, size: 17)).lineLimit(1)
                Text("\(vehicle.years) · \(vehicle.bodyType.label)").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(vehicle.tankLitres) L").font(ServoMapFont.display(.body, size: 17)).monospacedDigit()
                Text(vehicle.fuel).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
