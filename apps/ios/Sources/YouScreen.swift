import AuthenticationServices
import SwiftUI

/**
 * Everything that is yours, behind the avatar on the map (decisions 0004 and 0008), on paper with
 * no cards: who you are, your car as the one picture on the page, this month as a ruled row with its
 * fill-ups, and your saved stations as ledger rows on one price scale. Account, alerts and the rest
 * of the settings live in Settings.
 */
struct YouScreen: View {
    /** Pages pushed from You; `-tab <case name>` opens one at launch (see ServoMapApp). */
    enum Page: String, CaseIterable, Identifiable, Hashable {
        case saved = "Saved", log = "Log", car = "Your car", alerts = "Alerts", sources = "Data sources"
        var id: String { rawValue }
    }

    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var path: [Page]
    @State private var catalogue = VehicleCatalogue()
    @State private var flow: AddCarFlow.Start?
    @Namespace private var carZoom
    private let preset: (step: String, make: String, model: String)?

    /** Opens on the home, or straight onto `page` (launch arguments and deep links). */
    init(page: Page? = nil) {
        _path = State(initialValue: page.map { [$0] } ?? [])
        // Design screenshots: `-addCar make|model|years|details` opens the flow on that step,
        // for `-addCarModel Make/Model` (Mazda/CX-5 unless given).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-addCar"), i + 1 < args.count {
            let model = args.firstIndex(of: "-addCarModel").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? "Mazda/CX-5"
            let parts = model.split(separator: "/", maxSplits: 1).map(String.init)
            preset = (args[i + 1], parts.first ?? "Mazda", parts.count > 1 ? parts[1] : "CX-5")
            _flow = State(initialValue: .make)
        } else {
            preset = nil
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    identity
                    YouCarSection(zoom: carZoom) { flow = .make }
                    YouMonthSection()
                    YouSavedSection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
            .background(ServoMapColor.bg)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Page.self) { page in
                if page == .car {
                    CarPage().navigationTransition(.zoom(sourceID: YouCarSection.zoomID, in: carZoom))
                } else {
                    destination(page)
                        .navigationTitle(page.rawValue)
                        .navigationBarTitleDisplayMode(.large)
                }
            }
            .navigationDestination(for: Station.self) { StationDetail(station: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }.actionFont()
                }
            }
        }
        .environment(catalogue)
        .sheet(item: $flow) { start in AddCarFlow(start: start, catalogue: catalogue, preset: preset) }
        .presentationBackground(ServoMapColor.bg)
    }

    @ViewBuilder private func destination(_ page: Page) -> some View {
        switch page {
        case .saved: SavedScreen()
        case .log: LogScreen()
        case .car: CarPage()
        case .alerts: AlertsScreen()
        case .sources: DataSourcesScreen()
        }
    }

    // MARK: Identity

    private var identity: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                EditableAvatar()
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName).font(ServoMapFont.display(.title, weight: 500, size: 30))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Label {
                        Text(syncLine)
                    } icon: {
                        Image(systemName: account.account == nil ? "iphone" : "checkmark")
                            .foregroundStyle(account.account == nil ? ServoMapColor.ink3 : ServoMapColor.priceCheap)
                    }
                    .labelStyle(.titleAndIcon)
                    .font(ServoMapFont.body(.footnote))
                    .foregroundStyle(ServoMapColor.ink3)
                }
            }
            if account.account == nil { signIn }
            if case .failed(let message) = account.status {
                Text(message).font(ServoMapFont.small).foregroundStyle(ServoMapColor.priceExpensive)
            }
        }
    }

    private var syncLine: String {
        guard let signedIn = account.account else { return "Kept on this iPhone" }
        let provider = signedIn.provider == "google" ? "Google" : "Apple"
        guard let when = account.lastSynced else { return "Signed in with \(provider)" }
        return "Signed in with \(provider) · synced \(when.formatted(.relative(presentation: .named)))"
    }

    /** Apple first (App Store rule 4.8), Google when this build has a client id. */
    private var signIn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign in to keep your stations, log and car on all your devices.")
                .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { await account.signInWithApple(result, store: store, log: log) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 48)
            .clipShape(Capsule())
            if GoogleSignIn.clientID != nil {
                Button { Task { await account.signInWithGoogle(store: store, log: log) } } label: {
                    Label("Sign in with Google", systemImage: "g.circle.fill")
                        .actionFont().frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            }
        }
        .disabled(account.status == .signingIn)
        .overlay { if account.status == .signingIn { ProgressView() } }
    }
}

/** The avatar on the map: the user's photo or initials, a person glyph before any. */
struct AvatarButton: View {
    let action: () -> Void
    @State private var version = 0

    var body: some View {
        Button(action: action) {
            AvatarImage(size: 36, version: version)
        }
        .buttonStyle(.plain)
        .padding(4)
        .glassEffect(.regular, in: .circle)
        .onReceive(NotificationCenter.default.publisher(for: .avatarChanged)) { _ in version += 1 }
        .accessibilityLabel("You: your car, this month and saved stations")
    }
}
