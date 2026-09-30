import SwiftUI

/**
 * Your car (decision 0008): the picture, the make and model, the catalogue's figures with where
 * they came from, what a full tank costs nearby today, and what has gone into this car.
 */
struct CarPage: View {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(VehicleCatalogue.self) private var catalogue
    @State private var flow: AddCarFlow.Start?

    var body: some View {
        WithStoredCar { car in
            ScrollView {
                if car.exists { content(car) } else { empty }
            }
            .background(ServoMapColor.bg)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Change car") { flow = .make }.actionFont()
            }
        }
        .sheet(item: $flow) { start in AddCarFlow(start: start, catalogue: catalogue) }
    }

    private func content(_ car: StoredCar) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            CarPicture(path: car.imagePath, make: car.make, subject: car.title, labelled: true)
                .frame(height: 197)
                .padding(.top, 8)
            identity(car).padding(.top, 8)
            specs(car).padding(.top, 20)
            FullTankToday(car: car).padding(.top, 28)
            history(car).padding(.top, 28)
            Button { flow = .edit } label: {
                Text("Edit name and tank").frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .actionFont()
            .padding(.top, 24)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private func identity(_ car: StoredCar) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let make = car.make {
                HStack(spacing: 10) {
                    CarMark(make: make, size: 28)
                    Text(make).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink2)
                }
            }
            Text(car.vehicle?.model ?? car.title).font(ServoMapFont.display(.largeTitle, weight: 500))
                .accessibilityAddTraits(.isHeader)
            if let nickname = car.nickname {
                Text("“\(nickname)”").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
        }
    }

    private func specs(_ car: StoredCar) -> some View {
        VStack(spacing: 0) {
            if let vehicle = car.vehicle {
                SpecRow(label: "Generation") { Text("\(vehicle.years) · \(vehicle.bodyType.label)") }
                SpecRow(label: "Recommended fuel") { Text(vehicle.fuel) }
            } else {
                SpecRow(label: "Body") { Text(car.body.label) }
            }
            SpecRow(label: "Tank") {
                HStack(spacing: 8) {
                    if car.catalogueTankLitres > 0 {
                        Text(car.tankFromCatalogue ? "catalogue" : "your value")
                            .font(ServoMapFont.label).foregroundStyle(ServoMapColor.ink3)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r2).strokeBorder(ServoMapColor.line, lineWidth: 0.5))
                    }
                    Text("\(car.tankLitres) L").font(ServoMapFont.display(.body, size: 17)).monospacedDigit()
                }
            }
            if let vehicle = car.vehicle, let url = URL(string: vehicle.source) {
                SpecRow(label: "Source") {
                    Link(vehicle.sourceHost ?? vehicle.source, destination: url)
                        .font(ServoMapFont.body)
                        .underline(color: ServoMapColor.line)
                        .foregroundStyle(ServoMapColor.ink)
                }
            }
        }
        .overlay(alignment: .top) { Hairline() }
    }

    @ViewBuilder private func history(_ car: StoredCar) -> some View {
        let history = CarHistory.of(log.entries, since: car.since)
        VStack(alignment: .leading, spacing: 0) {
            SectionHeading(title: "In this car") {
                if let history {
                    Text("since \(history.since.formatted(.dateTime.day().month()))").foregroundStyle(ServoMapColor.ink3)
                        .font(ServoMapFont.body(.footnote))
                }
            }
            .padding(.bottom, 6)
            .overlay(alignment: .bottom) { if history == nil { Hairline() } }
            if let history {
                RuledFigures(figures: [
                    RuledFigure(label: "Fill-ups", value: "\(history.count)"),
                    RuledFigure(label: "Litres", value: history.litres.formatted(.number.precision(.fractionLength(1)))),
                    RuledFigure(label: "Avg paid", value: "\(history.averagePaid.formatted(.number.precision(.fractionLength(1))))¢"),
                ])
                // RuledFigures (Trends/TrendsParts.swift) insets itself for a full-width page; this page already is.
                .padding(.horizontal, -20)
            } else {
                Text("Fill-ups you log from now on add up here.")
                    .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                    .padding(.vertical, 10)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.side").font(ServoMapFont.display(.largeTitle)).foregroundStyle(ServoMapColor.ink3)
            Text("No car yet").font(ServoMapFont.display(.title3, weight: 500))
            Text("Add your car to price a full tank nearby and start the log on its fuel.")
                .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2).multilineTextAlignment(.center)
            Button("Add your car") { flow = .make }.buttonStyle(.glassProminent).buttonBorderShape(.capsule).actionFont()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.top, 48)
    }
}

extension AddCarFlow.Start: Identifiable {
    var id: Self { self }
}

/** A spec line: label at the left, value at the right, a hairline under it. */
private struct SpecRow<Value: View>: View {
    let label: String
    @ViewBuilder var value: Value

    var body: some View {
        HStack(alignment: .center) {
            Text(label).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
            Spacer(minLength: 12)
            value.font(ServoMapFont.body(.callout))
        }
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .combine)
    }
}

/**
 * "A full tank today": the tank at the cheapest, average and dearest current price nearby, as
 * three dots on one scale (docs/design/system.md: dots on a scale, not bars).
 */
private struct FullTankToday: View {
    let car: StoredCar
    @Environment(Store.self) private var store

    var body: some View {
        let tank = FullTank.near(store.stations, fuel: car.fuel, litres: car.tankLitres, loadedKm: store.radiusKm)
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "A full tank today") {
                Text("\(car.fuel.rawValue) within \(tank?.withinKm ?? 5) km").font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            if let tank {
                TankScale(tank: tank).frame(height: 64)
                Text("\(money(tank.spread)) between the cheapest and dearest tank near you.")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink2)
            } else {
                Text(store.loading ? "Loading prices…" : "No current \(car.fuel.rawValue) prices near \(store.placeName).")
                    .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
            }
        }
    }
}

/** Three dots on one hairline: cheapest at the left, dearest at the right, the average between. */
private struct TankScale: View {
    let tank: FullTank

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let dot: CGFloat = 14
            let x = dot / 2 + (w - dot) * tank.averagePosition
            ZStack(alignment: .topLeading) {
                Hairline().frame(width: w).offset(y: 30)
                Circle().fill(ServoMapColor.priceCheap).frame(width: dot, height: dot).offset(y: 24)
                Circle().fill(ServoMapColor.surface).overlay(Circle().strokeBorder(ServoMapColor.ink, lineWidth: 2))
                    .frame(width: dot, height: dot).offset(x: x - dot / 2, y: 24)
                Circle().fill(ServoMapColor.priceExpensive).frame(width: dot, height: dot).offset(x: w - dot, y: 24)
                figure("Cheapest", tank.cheapest, ServoMapColor.priceCheap, weight: 600)
                    .frame(width: w, alignment: .leading)
                figure("Average", tank.average, ServoMapColor.ink2)
                    .fixedSize()
                    .position(x: min(max(x, 60), w - 60), y: 30)
                figure("Dearest", tank.dearest, ServoMapColor.priceExpensive)
                    .frame(width: w, alignment: .trailing)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A full tank costs \(money(tank.cheapest)) at the cheapest, \(money(tank.average)) on average and \(money(tank.dearest)) at the dearest")
    }

    /** A dot's caption above the line and its dollar figure below. */
    private func figure(_ label: String, _ dollars: Double, _ tint: Color, weight: Int = 400) -> some View {
        VStack(alignment: label == "Dearest" ? .trailing : .leading, spacing: 0) {
            Text(label).font(ServoMapFont.body(.caption, weight: weight)).foregroundStyle(tint)
            Spacer().frame(height: 24)
            Text(money(dollars)).font(ServoMapFont.display(.callout, size: 16)).monospacedDigit()
        }
    }
}
