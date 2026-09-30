import SwiftUI

/**
 * "Your car" on You: the one picture on the page, on paper with no card, its name and years, and a
 * ruled row of tank, fuel and what a full tank costs at the cheapest nearby. The picture zooms
 * into the Your car page.
 */
struct YouCarSection: View {
    static let zoomID = "car"
    let zoom: Namespace.ID
    let addCar: () -> Void
    @Environment(Store.self) private var store

    var body: some View {
        WithStoredCar { car in
            VStack(alignment: .leading, spacing: 0) {
                SectionHeading(title: "Your car") {
                    if car.exists { NavigationLink("Details", value: YouScreen.Page.car) }
                }
                if car.exists { details(car) } else { empty }
            }
        }
    }

    private func details(_ car: StoredCar) -> some View {
        let tank = FullTank.near(store.stations, fuel: car.fuel, litres: car.tankLitres, loadedKm: store.radiusKm)
        return VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: YouScreen.Page.car) {
                CarPicture(path: car.imagePath, make: car.make, subject: car.title, labelled: true)
                    .frame(height: 186)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .contentShape(.rect)
                    .matchedTransitionSource(id: Self.zoomID, in: zoom)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your car's details")
            HStack(alignment: .firstTextBaseline) {
                Text(car.title).font(ServoMapFont.display(.title2, size: 24)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Text(car.caption).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
            }
            RuledFigures(figures: [
                RuledFigure(label: "Tank", value: "\(car.tankLitres) L"),
                RuledFigure(label: "Fuel", value: car.fuel.rawValue),
                RuledFigure(label: "Full tank now", value: tank.map { money($0.cheapest) } ?? "–", color: ServoMapColor.priceCheap),
            ])
            // RuledFigures (Trends/TrendsParts.swift) insets itself for a full-width page; this section already is.
            .padding(.horizontal, -20)
            .padding(.top, 12)
            if let tank {
                Text("At \(tank.cheapestPrice.formatted(.number.precision(.fractionLength(1))))¢, the cheapest \(car.fuel.rawValue) within \(tank.withinKm) km.")
                    .font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                    .padding(.top, 6)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your car to see what a full tank costs nearby, and to open the map on its fuel.")
                .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
            Button(action: addCar) {
                Label("Add your car", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .actionFont()
        }
        .padding(.top, 10)
    }
}
