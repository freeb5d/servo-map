import MapKit
import SwiftUI

/**
 * The Nearby tab: the map under the tab bar, with the fuel switch, avatar and map controls on top.
 * The results list is a sheet raised from the tab bar's accessory or by picking a station (see RootTabs).
 */
struct MapScreen: View {
    @Environment(Store.self) private var store
    @Binding var showResults: Bool
    @State private var detent: PresentationDetent = .medium
    /** The You sheet (saved, log, car, alerts) and the page it opens on. */
    @State private var showYou: Bool
    @State private var youPage: YouScreen.Page?
    @State private var selected: Station?
    @State private var showFilters: Bool
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: Store.sydney.lat, longitude: Store.sydney.lng),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)))
    @State private var location = Location()
    /** Stations drawn as full tags; recomputed whenever the camera settles or the list changes. */
    @State private var placement = TagPlacement.Result()
    /** Stations drawn as dots (see MapDots), chosen with `placement`; nil (every dot) until the camera first settles. */
    @State private var dots: Set<String>?
    /** The fetch a settled pan may start, held briefly so a run of flicks makes one request. */
    @State private var pendingFetch: Task<Void, Never>?
    @State private var proxy: MapProxy?
    @State private var mapSize: CGSize = .zero
    /** How much of the map's foot the tab bar and its accessory cover. */
    @State private var mapBottomInset: CGFloat = 0
    /** Set before the app moves the camera itself, so that move is not mistaken for a user pan. */
    @State private var appMoved = true
    /** True until the first load and after locating: the next result set reframes the camera. */
    @State private var reframeOnLoad = true
    /** Region the camera last settled on, whether the app or the user moved it. */
    @State private var lastRegion: MKCoordinateRegion?
    private let openDetail: Bool

    init(route: LaunchRoute, showResults: Binding<Bool>) {
        _showResults = showResults
        openDetail = route.openDetail
        _showYou = State(initialValue: route.openYou)
        _youPage = State(initialValue: route.youPage)
        _showFilters = State(initialValue: route.openFilters)
    }

    var body: some View {
        MapReader { reader in
            // Compared by what it draws: this closure re-runs on every settle, and the sheet's detent
            // re-runs the body, without redrawing the map. A skipped map keeps its earlier
            // `onSettle`, whose proxy still converts for the live camera.
            StationMap(camera: $camera, selection: $selected, selected: selected, placement: placement, dots: dots) { region in
                settle(on: region, reader)
            }
            .equatable()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { mapSize = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { mapBottomInset = $0 }
        }
        .safeAreaInset(edge: .top) { topControls }
        // A new fuel or filter re-colours and re-ranks every dot; ease it like the design's list rows.
        .animation(ServoMapMotion.standard, value: store.fuel)
        .onChange(of: store.stations) {
            if reframeOnLoad { reframeOnLoad = false; frameCheapest() }
            placeTags()
        }
        .onChange(of: store.filters) { placeTags() }
        .onChange(of: showResults) { placeTags() }
        .onChange(of: selected) {
            guard let selected else { return }
            // Picking a station on the map shows its page at half height, so the map stays in view.
            if !showResults { detent = .medium; showResults = true }
            reveal(selected)
        }
        .sheet(isPresented: $showResults, onDismiss: { selected = nil }) {
            ResultsSheet(selected: $selected)
                .presentationDetents([.medium, .large], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationBackground(ServoMapColor.bg)
                // While the list is up, it presents the You sheet and the filters itself.
                .modifier(MapModals(active: true, showYou: $showYou, youPage: youPage, showFilters: $showFilters))
        }
        .modifier(MapModals(active: !showResults, showYou: $showYou, youPage: youPage, showFilters: $showFilters))
        .sensoryFeedback(.selection, trigger: selected) { _, new in new != nil }
    }

    /** The camera came to rest: the list follows what is on screen, tags are re-placed, and prices fetched if needed. */
    private func settle(on region: MKCoordinateRegion, _ reader: MapProxy) {
        proxy = reader
        lastRegion = region
        store.viewport = viewport(reader)
        placeTags()
        followPan(to: region)
    }

    /**
     * Centres the map on the user at street level and keeps their dot there whatever the map does
     * next. Prices are fetched around them; the camera stays on them rather than reframing.
     */
    private func locate() async {
        guard let here = await location.locate() else { return }
        // A fetch a pan scheduled must not land after, and replace, the prices around the user.
        pendingFetch?.cancel()
        store.setUserLocation(here.latitude, here.longitude)
        appMoved = true
        // About 4 km across, with the user in the middle of the part of the map the chrome leaves.
        let around = MapFraming.region(showing: here.latitude, here.longitude, latDelta: 0.036, lngDelta: 0.036,
                                       in: visibleMap, of: mapSize)
        withAnimation(.smooth(duration: 0.6)) { camera = .region(mkRegion(around)) }
        await store.move(to: here.latitude, here.longitude, name: "you", radiusKm: 10)
    }

    /** The coordinates of the part of the map not under the sheet, the tab bar or the top controls. */
    private func viewport(_ reader: MapProxy) -> Viewport? {
        // Inset by half a cheapest-tag width, so the station it names has room for its whole tag.
        let r = visibleMap.insetBy(dx: 56, dy: 0).offsetBy(dx: 0, dy: 30).insetBy(dx: 0, dy: 15)
        guard r.width > 0, r.height > 0,
              let a = reader.convert(CGPoint(x: r.minX, y: r.minY), from: .local),
              let b = reader.convert(CGPoint(x: r.maxX, y: r.maxY), from: .local) else { return nil }
        return Viewport(minLat: min(a.latitude, b.latitude), maxLat: max(a.latitude, b.latitude),
                        minLng: min(a.longitude, b.longitude), maxLng: max(a.longitude, b.longitude))
    }

    /** The part of the map the sheet or the tab bar leaves uncovered, where tags are worth drawing. */
    private var visibleMap: CGRect {
        MapFraming.visible(size: mapSize, bottomInset: mapBottomInset, sheetUp: showResults)
    }

    /** Chooses tags and dots together, so a settle changes the map's annotations in one update. */
    private func placeTags() {
        guard let proxy else { return }
        let point: (Station) -> CGPoint? = {
            proxy.convert(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng), to: .local)
        }
        let next = TagPlacement.choose(store.ranked, id: \.id, point: point, visible: visibleMap)
        let nextDots = lastRegion.map { region in
            MapDots.choose(store.ranked + store.outdated, id: \.id, lat: \.lat, lng: \.lng,
                           degreesPerPoint: region.span.longitudeDelta / mapSize.width)
        }
        guard next != placement || nextDots != dots else { return }
        // Tags that change hands fade over the design system's 200 ms instead of popping.
        withAnimation(ServoMapMotion.standard) { placement = next; dots = nextDots }
    }

    /**
     * Once the map settles beyond what was fetched (see MapReload), fetch prices around the new
     * view. The camera is left where the user put it; moves the app makes itself are skipped via
     * `appMoved`. A short pause first lets a run of flicks end in one request.
     */
    private func followPan(to region: MKCoordinateRegion) {
        if appMoved { appMoved = false; return }
        let reach = MapReload.reachKm(latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta)
        let showing = MapReload.Area(lat: region.center.latitude, lng: region.center.longitude, radiusKm: Store.fetchRadius(reach))
        pendingFetch?.cancel()
        pendingFetch = Task {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            let loaded = MapReload.Area(lat: store.center.lat, lng: store.center.lng, radiusKm: store.radiusKm)
            guard MapReload.needed(loaded: loaded, capped: store.fetchWasCapped, showing: showing) else { return }
            // Past the view's edges, so zooming out shows the stations it uncovers and the next pans need nothing.
            let radius = MapReload.fetchKm(reachKm: showing.radiusKm)
            // Its own task: a later settle cancels the pause above, never a request already sent.
            Task { await store.move(to: showing.lat, showing.lng, name: "this area", radiusKm: radius) }
        }
    }

    /** Brings a picked station into the visible part of the map, keeping the zoom. */
    private func reveal(_ station: Station) {
        let visible = visibleMap
        guard let point = proxy?.convert(CLLocationCoordinate2D(latitude: station.lat, longitude: station.lng), to: .local),
              !visible.insetBy(dx: 30, dy: 30).contains(point),
              let region = lastRegion, mapSize.width > 0, mapSize.height > 0 else { return }
        let target = MapFraming.region(showing: station.lat, station.lng,
                                       latDelta: region.span.latitudeDelta * visible.height / mapSize.height,
                                       lngDelta: region.span.longitudeDelta * visible.width / mapSize.width,
                                       in: visible, of: mapSize)
        appMoved = true
        withAnimation(.smooth(duration: 0.6)) { camera = .region(mkRegion(target)) }
    }

    /** Frames the tagged (cheapest) stations in the part of the map the chrome leaves visible. */
    private func frameCheapest() {
        let top = store.ranked.prefix(8)
        guard let minLat = top.map(\.lat).min(), let maxLat = top.map(\.lat).max(),
              let minLng = top.map(\.lng).min(), let maxLng = top.map(\.lng).max() else { return }
        let target = MapFraming.region(showing: (minLat + maxLat) / 2, (minLng + maxLng) / 2,
                                       latDelta: max(maxLat - minLat, 0.02) * 1.4,
                                       lngDelta: max(maxLng - minLng, 0.02) * 1.4,
                                       in: visibleMap, of: mapSize)
        appMoved = true
        camera = .region(mkRegion(target))
        if openDetail, selected == nil { selected = store.ranked.first }
    }

    private func mkRegion(_ r: MapFraming.Region) -> MKCoordinateRegion {
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: r.lat, longitude: r.lng),
                           span: MKCoordinateSpan(latitudeDelta: r.latDelta, longitudeDelta: r.lngDelta))
    }

    /**
     * As in Maps: the fuel switch and the avatar across the top, and the map's own controls (filters,
     * location) stacked in one glass column on the right, so the fuel names never truncate.
     */
    private var topControls: some View {
        @Bindable var store = store
        return VStack(alignment: .trailing, spacing: 10) {
            HStack(spacing: 10) {
                Picker("Fuel", selection: $store.fuel) {
                    ForEach(FuelType.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                // Map labels showed through the bare segmented control; glass blurs them out.
                .padding(3)
                .glassEffect(.regular, in: .capsule)
                AvatarButton { youPage = nil; showYou = true }
            }
            VStack(spacing: 0) {
                Button { showFilters = true } label: {
                    Image(systemName: store.filters.activeCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                        .mapControl()
                }
                .accessibilityLabel(store.filters.activeCount > 0 ? "Filters, \(store.filters.activeCount) on" : "Filters")
                Divider().frame(width: 28)
                Button { Task { await locate() } } label: {
                    Image(systemName: location.state == .denied ? "location.slash" : store.located ? "location.fill" : "location")
                        .symbolEffect(.pulse, isActive: location.state == .locating)
                        .mapControl()
                }
                .accessibilityLabel(store.located ? "Showing prices near you" : "Use my location")
            }
            .buttonStyle(.plain)
            .foregroundStyle(ServoMapColor.ink)
            .padding(.vertical, 4)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

/** Map annotation: brand seal cell and price on a paper tag; the tier colour is a small square. */
struct PriceTag: View {
    let family: BrandFamily
    let cents: Double
    let tier: PriceTier
    let active: Bool

    var body: some View {
        HStack(spacing: 0) {
            BrandSeal(family: family, size: 16)
                .padding(.leading, 2)
            HStack(spacing: 3) {
                Text(cents, format: .number.precision(.fractionLength(1)))
                    .font(ServoMapFont.display(.caption, size: 12)).monospacedDigit()
                Rectangle().fill(active ? ServoMapColor.surface : tier.color).frame(width: 4, height: 4)
            }
            .padding(.horizontal, 5)
        }
        .fixedSize()
        .frame(height: 20)
        // Map tags stay map-sized: the list below carries the same prices at the reader's text size.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .foregroundStyle(active ? ServoMapColor.surface : ServoMapColor.ink)
        .background(active ? ServoMapColor.ink : ServoMapColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: ServoMapRadius.r1))
        .overlay(RoundedRectangle(cornerRadius: ServoMapRadius.r1).strokeBorder(active ? ServoMapColor.ink : ServoMapColor.line))
        // Selection inverts the tag; the colour change eases rather than snapping.
        .animation(ServoMapMotion.standard, value: active)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/**
 * The cheapest station's tag: larger, filled in the cheap tier colour and labelled, so the answer
 * to "where is cheapest" is the first thing on the map. A soft halo breathes (opacity only).
 */
struct CheapestTag: View {
    let family: BrandFamily
    let cents: Double
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            BrandSeal(family: family, size: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text("Cheapest").font(ServoMapFont.body(.caption2, weight: 700, size: 9))
                Text(cents, format: .number.precision(.fractionLength(1)))
                    .font(ServoMapFont.display(.body, size: 17)).monospacedDigit()
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .fixedSize()
        .dynamicTypeSize(...DynamicTypeSize.large)
        .foregroundStyle(ServoMapColor.surface)
        .background(active ? ServoMapColor.ink : ServoMapColor.priceCheap, in: RoundedRectangle(cornerRadius: ServoMapRadius.r3))
        .background {
            RoundedRectangle(cornerRadius: ServoMapRadius.r3 + 4)
                .fill(ServoMapColor.priceCheap)
                .padding(-4)
                .phaseAnimator(reduceMotion ? [0.18] : [0.08, 0.3]) { halo, opacity in
                    halo.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 1.4) }
        }
        .animation(ServoMapMotion.standard, value: active)
        .accessibilityLabel("Cheapest, \(family.name), \(cents.formatted(.number.precision(.fractionLength(1)))) cents")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/**
 * The You sheet and the filters, presented by whichever view is on top: the map, or the results
 * sheet while it is up (a view already presenting a sheet cannot present a second one).
 */
private struct MapModals: ViewModifier {
    let active: Bool
    @Binding var showYou: Bool
    let youPage: YouScreen.Page?
    @Binding var showFilters: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: gated($showYou)) { YouScreen(page: youPage) }
            .sheet(isPresented: gated($showFilters)) { FilterSheet() }
    }

    private func gated(_ flag: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { active && flag.wrappedValue }, set: { flag.wrappedValue = $0 })
    }
}

private extension View {
    /** Map control glyphs: semibold at body size in a 44 pt square, so they read over the map. */
    func mapControl() -> some View {
        font(ServoMapFont.body(.body, weight: 600)).frame(width: 44, height: 44).contentShape(Rectangle())
    }
}
