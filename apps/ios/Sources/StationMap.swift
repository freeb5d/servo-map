import MapKit
import SwiftUI

/**
 * The map itself: a dot or a price tag for every station, and the user's location.
 *
 * It is a view of its own, compared by what it draws, because every update of a SwiftUI `Map`
 * makes MapKit lay out every annotation view again, a hundred milliseconds or more with a few
 * hundred stations on screen. `MapReader` re-runs its content each time the camera settles, and
 * the screen re-runs its body for the sheet's detent and tabs; neither changes what the map
 * draws, so neither should pay for that update.
 */
struct StationMap: View {
    @Environment(Store.self) private var store
    @Binding var camera: MapCameraPosition
    @Binding var selection: Station?
    /** `selection`'s value when the screen last drew: bindings compare equal whatever they hold. */
    let selected: Station?
    let placement: TagPlacement.Result
    /** Stations drawn as dots (see MapDots); nil draws every one. */
    let dots: Set<String>?
    /** Called with the region each time the camera comes to rest. */
    let onSettle: (MKCoordinateRegion) -> Void
    /** Settings › Map can leave week-old prices off the map; a picked one still shows. */
    // Not private: a private wrapper would make the memberwise initialiser private too.
    @AppStorage(StorageKey.showOldPrices) var showOld = true

    var body: some View {
        Map(position: $camera, selection: $selection) {
            if store.located { UserAnnotation() }
            // Stations whose price is more than a week old: hollow, so they read as "a station is here"
            // without competing with current prices. Still selectable.
            ForEach(showOld ? store.outdated.filter { $0 != selected && drawsDot($0) } : []) { station in
                Annotation(station.name, coordinate: station.coordinate) {
                    Circle()
                        .stroke(ServoMapColor.ink3, lineWidth: 1.5)
                        .background(Circle().fill(ServoMapColor.surface))
                        .frame(width: MapDots.size, height: MapDots.size)
                }
                .annotationTitles(.hidden)
                .tag(station)
            }
            // Tags go to the cheapest stations that have room; the rest are dots, so the map reads at a glance.
            // Dots are added first and tags after, so a tag is never covered by a neighbour's dot.
            ForEach(store.ranked.filter { !showsTag($0) && !placement.hiddenDots.contains($0.id) && drawsDot($0) }) { station in
                if let p = station.price(store.fuel) {
                    Annotation(station.name, coordinate: station.coordinate) {
                        Circle()
                            .fill(store.range.tier(p.price).color)
                            .stroke(ServoMapColor.surface, lineWidth: 1.5)
                            .frame(width: MapDots.size, height: MapDots.size)
                    }
                    .annotationTitles(.hidden)
                    .tag(station)
                }
            }
            // A picked station that is not ranked (outdated, or filtered out) still gets its tag.
            if let selected, !store.ranked.contains(selected), let p = selected.price(store.fuel) {
                Annotation(selected.name, coordinate: selected.coordinate, anchor: .bottom) {
                    PriceTag(family: selected.family, cents: p.price, tier: store.range.tier(p.price), active: true)
                }
                .annotationTitles(.hidden)
                .tag(selected)
            }
            // Drawn last, so the cheapest tag sits on top of its neighbours.
            ForEach(store.ranked.filter(showsTag).reversed()) { station in
                if let p = station.price(store.fuel) {
                    Annotation(station.name, coordinate: station.coordinate, anchor: .bottom) {
                        if station.id == store.cheapestInView?.id {
                            CheapestTag(family: station.family, cents: p.price, active: selected == station)
                        } else {
                            PriceTag(family: station.family, cents: p.price, tier: store.range.tier(p.price), active: selected == station)
                        }
                    }
                    .annotationTitles(.hidden)
                    .tag(station)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { onSettle($0.region) }
    }

    /**
     * The cheapest station on screen always has its tag, whatever the placement pass chose. The map
     * reads `cheapestInView`, not `inView`, so a settle that keeps the same cheapest station does
     * not redraw every annotation.
     */
    private func showsTag(_ station: Station) -> Bool {
        placement.tagged.contains(station.id) || selected == station || station.id == store.cheapestInView?.id
    }

    private func drawsDot(_ station: Station) -> Bool { dots?.contains(station.id) ?? true }
}

extension StationMap: Equatable {
    /** Equal when it would draw the same; the store's changes reach it through Observation instead. */
    nonisolated static func == (a: StationMap, b: StationMap) -> Bool {
        a.selected == b.selected && a.placement == b.placement && a.dots == b.dots
    }
}
