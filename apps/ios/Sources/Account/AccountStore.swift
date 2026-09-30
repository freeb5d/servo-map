import AuthenticationServices
import Foundation
import Observation

/**
 * The signed-in account and its sync (decision 0004). Signing in is optional; until then the app
 * keeps everything on the device. On sign-in, what is on the device merges into the account; after
 * that each change is pushed as it happens and the account is pulled when the app opens.
 */
@MainActor @Observable
final class AccountStore {
    enum Status: Equatable { case signedOut, signingIn, signedIn, failed(String) }

    private(set) var account: AccountDTO?
    private(set) var status: Status = .signedOut
    private(set) var lastSynced: Date?
    private var token: String?
    private let google = GoogleSignIn()

    var initials: String? {
        guard let account else { return nil }
        let source = account.name ?? account.email ?? ""
        let letters = source.split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." }).prefix(2).compactMap(\.first)
        return letters.isEmpty ? nil : String(letters).uppercased()
    }

    var displayName: String { account?.name ?? account?.email ?? "You" }

    init() {
        token = Keychain.read()
        if let data = UserDefaults.standard.data(forKey: "account"), let saved = try? JSONDecoder().decode(AccountDTO.self, from: data), token != nil {
            account = saved
            status = .signedIn
        }
    }

    private var api: AccountAPI { AccountAPI(token: token) }

    // MARK: Sign in and out

    func signInWithApple(_ result: Result<ASAuthorization, Error>, store: Store, log: FillUpLog) async {
        guard case .success(let auth) = result,
              let credential = auth.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken, let identityToken = String(data: data, encoding: .utf8) else {
            if case .failure(let e) = result, (e as? ASAuthorizationError)?.code == .canceled { return }
            status = .failed("Sign in with Apple didn't finish. Try again.")
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        await complete(provider: "apple", identityToken: identityToken, name: name.isEmpty ? nil : name, store: store, log: log)
    }

    func signInWithGoogle(store: Store, log: FillUpLog) async {
        do {
            status = .signingIn
            let idToken = try await google.signIn()
            await complete(provider: "google", identityToken: idToken, name: nil, store: store, log: log)
        } catch GoogleSignIn.Failure.cancelled {
            status = account == nil ? .signedOut : .signedIn
        } catch {
            status = .failed("Google sign-in didn't finish. Try again.")
        }
    }

    private func complete(provider: String, identityToken: String, name: String?, store: Store, log: FillUpLog) async {
        status = .signingIn
        do {
            let session = try await AccountAPI(token: nil).signIn(provider: provider, identityToken: identityToken, name: name)
            token = session.token
            Keychain.save(session.token)
            remember(session.account)
            status = .signedIn
            await mergeOnSignIn(store: store, log: log)
        } catch {
            status = .failed("Couldn't reach ServoMap to sign in. Check your connection.")
        }
    }

    func signOut() {
        token = nil
        account = nil
        Keychain.delete()
        UserDefaults.standard.removeObject(forKey: "account")
        status = .signedOut
    }

    /** Deletes the account and everything stored with it on the server; the device keeps its copy. */
    func deleteAccount() async -> Bool {
        do {
            try await api.deleteAccount()
            signOut()
            return true
        } catch {
            status = .failed("Couldn't delete the account. Check your connection and try again.")
            return false
        }
    }

    private func remember(_ account: AccountDTO) {
        self.account = account
        UserDefaults.standard.set(try? JSONEncoder().encode(account), forKey: "account")
    }

    // MARK: Sync

    /** First sign-in on this device: both sides end up with the union of saved stations and fill-ups. */
    func mergeOnSignIn(store: Store, log: FillUpLog) async {
        await pull(store: store, log: log, pushLocal: true)
    }

    /** Opening the app: take what other devices added. */
    func refresh(store: Store, log: FillUpLog) async {
        guard token != nil else { return }
        await pull(store: store, log: log, pushLocal: false)
    }

    private func pull(store: Store, log: FillUpLog, pushLocal: Bool) async {
        do {
            let me = try await api.me()
            remember(me.account)
            let union = Array(NSOrderedSet(array: store.savedIDs + me.savedStationIds)) as? [String] ?? store.savedIDs
            if union != store.savedIDs { store.savedIDs = union }
            log.merge(me.fillUps.compactMap(FillUp.init))
            if let car = me.car, !pushLocal || CarSettings.isDefault { CarSettings.apply(car, store: store) }
            AlertPrefs.apply(me.alerts)
            if pushLocal {
                try await api.putSaved(store.savedIDs)
                let remoteIDs = Set(me.fillUps.map(\.id))
                try await api.putFillUps(log.entries.filter { !remoteIDs.contains($0.id.uuidString) }.map(\.dto))
                if !CarSettings.isDefault { try await api.putCar(CarSettings.current) }
                try await api.putAlerts(AlertPrefs.current)
            }
            lastSynced = .now
        } catch AccountAPI.Failure.unauthenticated {
            signOut()
        } catch {
            // Offline: keep working locally; the next change or launch tries again.
        }
    }

    func pushSaved(_ ids: [String]) async { await attempt { try await $0.putSaved(ids) } }
    func pushFillUps(_ fills: [FillUp]) async { await attempt { try await $0.putFillUps(fills.map(\.dto)) } }
    func pushDeletedFillUp(_ id: UUID) async { await attempt { try await $0.deleteFillUp(id.uuidString) } }
    func pushCar() async { await attempt { try await $0.putCar(CarSettings.current) } }
    func pushAlerts() async { await attempt { try await $0.putAlerts(AlertPrefs.current) } }
    func pushDevice(_ hex: String) async {
        #if DEBUG
        let environment = "development"
        #else
        let environment = "production"
        #endif
        await attempt { try await $0.putDevice(hex, environment: environment) }
    }

    private func attempt(_ work: (AccountAPI) async throws -> Void) async {
        guard token != nil else { return }
        do {
            try await work(api)
            lastSynced = .now
        } catch AccountAPI.Failure.unauthenticated {
            signOut()
        } catch {}
    }
}

/** The car settings the Car page edits, read and written as one value for sync. */
@MainActor
enum CarSettings {
    private static let d = UserDefaults.standard

    static var isDefault: Bool { d.string(forKey: "carVehicleID") == nil && (d.string(forKey: "carName") ?? "My car") == "My car" }

    static var current: CarDTO {
        CarDTO(vehicleId: d.string(forKey: "carVehicleID").flatMap { $0.isEmpty ? nil : $0 },
               name: d.string(forKey: "carName") ?? "My car",
               body: d.string(forKey: "carBody") ?? BodyType.hatch.rawValue,
               paint: d.string(forKey: "carPaint") ?? "silver",
               fuel: d.string(forKey: "defaultFuel") ?? FuelType.u91.rawValue,
               tankLitres: d.object(forKey: "tankLitres") as? Int ?? 50,
               catalogueTankLitres: (d.object(forKey: "catalogueTankLitres") as? Int).flatMap { $0 > 0 ? $0 : nil })
    }

    static func apply(_ car: CarDTO, store: Store) {
        d.set(car.vehicleId ?? "", forKey: "carVehicleID")
        d.set(car.name, forKey: "carName")
        d.set(car.body, forKey: "carBody")
        d.set(car.paint, forKey: "carPaint")
        d.set(car.fuel, forKey: "defaultFuel")
        d.set(car.tankLitres, forKey: "tankLitres")
        d.set(car.catalogueTankLitres ?? 0, forKey: "catalogueTankLitres")
        if let f = FuelType(rawValue: car.fuel) { store.fuel = f }
    }
}

/** Alert switches and quiet hours, as one value for sync. */
@MainActor
enum AlertPrefs {
    private static let d = UserDefaults.standard

    static var current: AlertsDTO {
        let home = (d.object(forKey: "homeLat") as? Double).flatMap { lat in (d.object(forKey: "homeLng") as? Double).map { AlertsDTO.Home(lat: lat, lng: $0) } }
        return AlertsDTO(priceDrop: d.bool(forKey: "priceAlerts"), cycleLow: d.bool(forKey: "alertCycleLow"),
                         quietStart: d.object(forKey: "quietStart") as? Int ?? 22, quietEnd: d.object(forKey: "quietEnd") as? Int ?? 7, home: home)
    }

    static func apply(_ a: AlertsDTO) {
        d.set(a.priceDrop, forKey: "priceAlerts")
        d.set(a.cycleLow, forKey: "alertCycleLow")
        d.set(a.quietStart, forKey: "quietStart")
        d.set(a.quietEnd, forKey: "quietEnd")
    }
}
