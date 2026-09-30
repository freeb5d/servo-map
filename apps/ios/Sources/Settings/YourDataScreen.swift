import SwiftUI

/** Settings › Your data: take the fill-up log away as CSV, or clear what this iPhone keeps. */
struct YourDataScreen: View {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(AccountStore.self) private var account
    @State private var confirmClear = false
    @State private var cleared = false

    var body: some View {
        PlainPage(intro: "Your fill-ups, saved stations and car live on this iPhone, and in your account when you sign in.") {
            PlainGroup(title: "Export", footer: "A CSV file, for Numbers or Excel.", inset: 0) {
                ShareLink(item: FillUpExport(entries: log.entries), preview: SharePreview("ServoMap fill-ups")) {
                    PlainRow(title: "Fill-up log", value: count, chevron: false)
                }
                .buttonStyle(.plainRow)
                .disabled(log.entries.isEmpty)
            }
            PlainGroup(title: "Clear", footer: clearNote, inset: 0) {
                Button { confirmClear = true } label: {
                    PlainRow(title: "Clear this iPhone", chevron: false, tint: ServoMapColor.priceExpensive)
                }
                .buttonStyle(.plainRow)
            }
        }
        .confirmationDialog("Clear ServoMap on this iPhone?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear this iPhone", role: .destructive) {
                LocalData.clear(store: store, log: log, account: account)
                cleared.toggle()
            }
        } message: {
            Text(account.account == nil
                 ? "Your fill-up log, saved stations, car, home and photo are removed from this iPhone. This cannot be undone."
                 : "You are signed out first, so your account keeps its copy. Your fill-up log, saved stations, car, home and photo are then removed from this iPhone.")
        }
        .sensoryFeedback(.success, trigger: cleared)
    }

    private var count: String {
        log.entries.count == 1 ? "1 fill-up" : "\(log.entries.count) fill-ups"
    }

    private var clearNote: String {
        account.account == nil
            ? "Removes your fill-up log, saved stations, car, home and photo from this iPhone."
            : "Signs you out first, so your account keeps everything; then removes it from this iPhone."
    }
}

/** Everything personal the app keeps on the device; settings such as Appearance stay. */
@MainActor
enum LocalData {
    /** Keys holding the user's own data, cleared with it. */
    static let keys = [
        StorageKey.saved, StorageKey.recentSearches, StorageKey.carName, StorageKey.carVehicleID, StorageKey.carVehicle,
        StorageKey.carBody, StorageKey.carSince, StorageKey.tankLitres, StorageKey.catalogueTankLitres, StorageKey.defaultFuel,
        StorageKey.homeLat, StorageKey.homeLng,
    ]

    /**
     * Signs out first when signed in: AccountSync pushes every removal to the account, and clearing
     * this iPhone must not empty the account too.
     */
    static func clear(store: Store, log: FillUpLog, account: AccountStore, defaults: UserDefaults = .standard) {
        if account.account != nil { account.signOut() }
        log.remove(Set(log.entries.map(\.id)))
        store.savedIDs = []
        for key in keys { defaults.removeObject(forKey: key) }
        AvatarPhoto.remove()
        NotificationCenter.default.post(name: .avatarChanged, object: nil)
    }
}
