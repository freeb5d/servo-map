import MapKit
import SwiftUI

struct MapScreen: View {
    @Environment(Store.self) private var store
    @State private var detent: PresentationDetent
    @State private var tab: String
    /** The You sheet (saved, log, car, alerts) and the page it opens on. */
    @State private var showYou = false
    @State private var youPage: YouScreen.Page?
    @State private var selected: Station?
    @State private var showFilters: Bool
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: Store.sydney.lat, longitude: Store.sydney.lng),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)))
    @State private var location = Location()
    /** Stations drawn as full tags; recomputed whenever the camera settles or the list changes. */
    @State private var placement = TagPlacement.Result()
    @State private var proxy: MapProxy?
    @State private var mapSize: CGSize = .zero
    /** Set before the app moves the camera itself, so that move is not mistaken for a user pan. */
    @State private var appMoved = true
    /** True until the first load and after locating: the next result set reframes the camera. */
    @State private var reframeOnLoad = true
    /** Region the camera last settled on, whether the app or the user moved it. */
    @State private var lastRegion: MKCoordinateRegion?
    private let openDetail: Bool

    init(tab: String = "map", openFilters: Bool = false, openDetail: Bool = false) {
        self.openDetail = openDetail
        // Saved and Log moved into the You sheet; their launch names open it on that page.
        let page = YouScreen.Page.allCases.first { "\($0)" == tab }
        if tab == "you" || page != nil {
            _showYou = State(initialValue: true)
            _youPage = State(initialValue: page)
        }
        let tab = ["trends", "search"].contains(tab) ? tab : "map"
        _tab = State(initialValue: tab)
        _detent = State(initialValue: tab == "map" ? .medium : .large)
        _showFilters = State(initialValue: openFilters)
    }

    var body: some View {
        MapReader { reader in
        Map(position: $camera, selection: $selected) {
            if store.located { UserAnnotation() }
            // Stations whose price is more than a week old: hollow, so they read as "a station is here"
            // without competing with current prices. Still selectable.
            ForEach(store.outdated.filter { $0 != selected }) { station in
                Annotation(station.name, coordinate: station.coordinate) {
                    Circle()
                        .stroke(ServoMapColor.ink3, lineWidth: 1.5)
                        .background(Circle().fill(ServoMapColor.surface))
                        .frame(width: 9, height: 9)
                }
                .annotationTitles(.hidden)
                .tag(station)
            }
            // Tags go to the cheapest stations that have room; the rest are dots, so the map reads at a glance.
            // Dots are added first and tags after, so a tag is never covered by a neighbour's dot.
            ForEach(store.ranked.filter { !showsTag($0) && !placement.hiddenDots.contains($0.id) }) { station in
                if let p = station.price(store.fuel) {
                    Annotation(station.name, coordinate: station.coordinate) {
                        Circle()
                            .fill(store.range.tier(p.price).color)
                            .stroke(ServoMapColor.surface, lineWidth: 1.5)
                            .frame(width: 9, height: 9)
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
                        if station == store.inView.first {
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
        .onMapCameraChange(frequency: .onEnd) { context in
            proxy = reader
            lastRegion = context.region
            store.viewport = viewport(reader)
            placeTags()
            Task { await followPan(to: context.region) }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { mapSize = $0 }
        }
        .safeAreaInset(edge: .top) { topControls }
        // A new fuel or filter re-colours and re-ranks every dot; ease it like the design's list rows.
        .animation(ServoMapMotion.standard, value: store.fuel)
        .onChange(of: store.stations) {
            if reframeOnLoad { reframeOnLoad = false; frameCheapest() }
            placeTags()
        }
        .onChange(of: store.filters) { placeTags() }
        .onChange(of: detent) { placeTags() }
        .onChange(of: selected) { if let selected { reveal(selected) } }
        .sheet(isPresented: .constant(true)) {
            // Tabs live inside the sheet, as in Find My, so the map stays behind every section.
            TabView(selection: $tab) {
                Tab(value: "map") {
                    ResultsSheet(selected: $selected, showFilters: $showFilters).modifier(page)
                } label: { tabLabel("Nearby", "fuelpump", "map") }
                Tab(value: "trends") { TrendsScreen().modifier(page) } label: { tabLabel("Trends", "chart.line.uptrend.xyaxis", "trends") }
                Tab(value: "search", role: .search) { SearchScreen().modifier(page) }
            }
            // As in Health: scrolling down folds the bar into one round button for the current tab,
            // with search on its own at the right.
            .tabBarMinimizeBehavior(.onScrollDown)
            .sheet(isPresented: $showYou) { YouScreen(page: youPage) }
            .overlay(alignment: .top) {
                if detent == collapsed {
                    CollapsedTabBar(tab: $tab) { value in
                        tab = value
                        detent = value == "map" ? .medium : .large
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                }
            }
            .onChange(of: tab) { detent = tab == "map" ? .medium : .large }
            // Picking a station on the map shows its page: back to Nearby, and up from the bar.
            .onChange(of: selected) {
                guard selected != nil else { return }
                tab = "map"
                if detent == collapsed { detent = .medium }
            }
                .presentationDetents([collapsed, .medium, .large], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .interactiveDismissDisabled()
                // Pulled down it is only the tab bar's own glass, floating over the map as in Find My;
                // raised it is paper, as in the design.
                .presentationBackground(detent == collapsed ? AnyShapeStyle(Color.clear) : AnyShapeStyle(ServoMapColor.bg))
        }
    }

    /** Pulled all the way down: just the tab bar, as in Find My. */
    private let collapsed = PresentationDetent.height(88)
    /** Collapsed, every page hides itself and the system tab bar; CollapsedTabBar stands in. */
    private var page: CollapsedPage { CollapsedPage(collapsed: detent == collapsed) }

    /** Selected tabs use the filled symbol and unselected ones the outline, so state reads by shape too. */
    private func tabLabel(_ title: String, _ symbol: String, _ value: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol).environment(\.symbolVariants, tab == value ? .fill : .none)
        }
    }

    /** The cheapest station on screen always has its tag, whatever the placement pass chose. */
    private func showsTag(_ station: Station) -> Bool {
        placement.tagged.contains(station.id) || selected == station || station == store.inView.first
    }

    /**
     * Centres the map on the user at street level and keeps their dot there whatever the map does
     * next. Prices are fetched around them; the camera stays on them rather than reframing.
     */
    private func locate() async {
        guard let here = await location.locate() else { return }
        store.setUserLocation(here.latitude, here.longitude)
        appMoved = true
        withAnimation(.smooth(duration: 0.6)) {
            camera = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: here.latitude - 0.012, longitude: here.longitude),
                latitudinalMeters: 6_000, longitudinalMeters: 6_000))
        }
        await store.move(to: here.latitude, here.longitude, name: "you", radiusKm: 10)
    }

    /** The coordinates of the part of the map not under the sheet or the top controls. */
    private func viewport(_ reader: MapProxy) -> Viewport? {
        // Inset by half a cheapest-tag width, so the station it names has room for its whole tag.
        let r = visibleMap.insetBy(dx: 56, dy: 0).offsetBy(dx: 0, dy: 30).insetBy(dx: 0, dy: 15)
        guard r.width > 0, r.height > 0,
              let a = reader.convert(CGPoint(x: r.minX, y: r.minY), from: .local),
              let b = reader.convert(CGPoint(x: r.maxX, y: r.maxY), from: .local) else { return nil }
        return Viewport(minLat: min(a.latitude, b.latitude), maxLat: max(a.latitude, b.latitude),
                        minLng: min(a.longitude, b.longitude), maxLng: max(a.longitude, b.longitude))
    }

    /** The part of the map the sheet leaves uncovered at its current height, where tags are worth drawing. */
    private var visibleMap: CGRect {
        let bottom = detent == collapsed ? mapSize.height - 120 : mapSize.height * 0.46
        return CGRect(x: 0, y: 70, width: mapSize.width, height: max(0, bottom - 70))
    }

    private func placeTags() {
        guard let proxy else { return }
        let next = TagPlacement.choose(store.ranked, id: \.id, point: {
            proxy.convert(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng), to: .local)
        }, visible: visibleMap)
        guard next != placement else { return }
        // Tags that change hands fade over the design system's 200 ms instead of popping.
        withAnimation(ServoMapMotion.standard) { placement = next }
    }

    /**
     * After the user drags the map more than 2 km, fetch prices around the new centre. The camera
     * is left where the user put it; moves the app makes itself are skipped via `appMoved`.
     */
    private func followPan(to region: MKCoordinateRegion) async {
        if appMoved { appMoved = false; return }
        let here = CLLocation(latitude: store.center.lat, longitude: store.center.lng)
        let there = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        // Fetch as far as the visible map reaches, so zooming out shows the stations it uncovers.
        let reach = Int((max(region.span.latitudeDelta, region.span.longitudeDelta) * 111 / 2).rounded(.up))
        let zoomedOut = reach > Int(Double(store.radiusKm) * 1.4)
        guard here.distance(from: there) > 2_000 || zoomedOut else { return }
        await store.move(to: region.center.latitude, region.center.longitude, name: "this area", radiusKm: reach)
    }

    /** Brings a picked station into the visible upper half of the map, keeping the zoom. */
    private func reveal(_ station: Station) {
        guard let point = proxy?.convert(CLLocationCoordinate2D(latitude: station.lat, longitude: station.lng), to: .local),
              !visibleMap.insetBy(dx: 30, dy: 30).contains(point),
              let region = lastRegion else { return }
        appMoved = true
        withAnimation(.smooth(duration: 0.6)) {
            camera = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: station.lat - region.span.latitudeDelta * 0.25, longitude: station.lng),
                span: region.span))
        }
    }

    /**
     * Frames the tagged (cheapest) stations in the part of the map the half-height sheet leaves
     * visible: the region is stretched downward so they land in its upper half.
     */
    private func frameCheapest() {
        let top = store.ranked.prefix(8)
        guard let minLat = top.map(\.lat).min(), let maxLat = top.map(\.lat).max(),
              let minLng = top.map(\.lng).min(), let maxLng = top.map(\.lng).max() else { return }
        let latSpan = max(maxLat - minLat, 0.02) * 1.4
        let lngSpan = max(maxLng - minLng, 0.02) * 1.4
        appMoved = true
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 - latSpan * 0.55, longitude: (minLng + maxLng) / 2),
            span: MKCoordinateSpan(latitudeDelta: latSpan * 2.3, longitudeDelta: lngSpan)))
        if openDetail, selected == nil { selected = store.ranked.first }
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

/** Hides a tab's page and the system tab bar while the sheet is pulled all the way down. */
private struct CollapsedPage: ViewModifier {
    let collapsed: Bool
    func body(content: Content) -> some View {
        content
            .opacity(collapsed ? 0 : 1)
            .background(TabBarHider(hidden: collapsed))
    }
}

/**
 * SwiftUI's tab bar visibility modifier has no effect on a TabView inside a sheet, so the
 * collapsed state reaches the UIKit tab bar that backs it directly.
 */
private struct TabBarHider: UIViewControllerRepresentable {
    let hidden: Bool

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        // The controller joins its tab bar controller's hierarchy only after this pass.
        DispatchQueue.main.async { controller.tabBarController?.tabBar.isHidden = hidden }
    }
}

private extension View {
    /** Map control glyphs: semibold at body size in a 44 pt square, so they read over the map. */
    func mapControl() -> some View {
        font(ServoMapFont.body(.body, weight: 600)).frame(width: 44, height: 44).contentShape(Rectangle())
    }
}
