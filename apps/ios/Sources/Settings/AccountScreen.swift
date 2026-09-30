import AuthenticationServices
import SwiftUI

/**
 * The top of Settings: signed in, the account as a row (avatar, name, how it syncs) opening its
 * page; signed out, the way to sign in (decision 0004: sign-in stays optional).
 */
struct AccountHeader: View {
    @Environment(AccountStore.self) private var account

    var body: some View {
        Group {
            if account.account != nil {
                NavigationLink(value: SettingsPage.account) {
                    HStack(spacing: ServoMapSpace.x4) {
                        AvatarImage(size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(account.displayName).font(ServoMapFont.body(.title3, weight: 600, size: 19))
                                .foregroundStyle(ServoMapColor.ink).lineLimit(1)
                            Text(AccountLines.sync(account)).font(ServoMapFont.body(.subheadline))
                                .foregroundStyle(ServoMapColor.ink3).lineLimit(1)
                        }
                        Spacer(minLength: ServoMapSpace.x2)
                        Image(systemName: "chevron.right")
                            .font(ServoMapFont.body(.footnote, weight: 600)).foregroundStyle(ServoMapColor.ink3)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, ServoMapSpace.x2)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plainRow)
            } else {
                SignInEntry()
            }
        }
        .padding(.top, ServoMapSpace.x5)
    }
}

/** The lines that say where your data is kept. */
@MainActor
enum AccountLines {
    /** "Apple account · synced 2 min ago". */
    static func sync(_ account: AccountStore) -> String {
        guard let dto = account.account else { return "Kept on this iPhone" }
        let provider = dto.provider == "google" ? "Google account" : "Apple account"
        if let when = account.lastSynced { return "\(provider) · synced \(when.formatted(.relative(presentation: .named)))" }
        return provider
    }
}

/** Sign in with Apple first (App Store rule 4.8), then Google when this build has a client id. */
struct SignInEntry: View {
    @Environment(Store.self) private var store
    @Environment(FillUpLog.self) private var log
    @Environment(AccountStore.self) private var account
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ServoMapSpace.x3) {
            Text("Sign in to keep your stations, log and car on all your devices.")
                .font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
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
            if case .failed(let message) = account.status {
                Text(message).font(ServoMapFont.small).foregroundStyle(ServoMapColor.priceExpensive)
            }
        }
        .disabled(account.status == .signingIn)
        .overlay { if account.status == .signingIn { ProgressView() } }
    }
}

/** Settings › Account: who is signed in, and signing out or deleting the account. */
struct AccountScreen: View {
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var deleting = false

    var body: some View {
        PlainPage {
            HStack(spacing: ServoMapSpace.x4) {
                EditableAvatar()
                VStack(alignment: .leading, spacing: 3) {
                    Text(account.displayName).font(ServoMapFont.display(.title2, weight: 600)).lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let email = account.account?.email, email != account.displayName {
                        Text(email).font(ServoMapFont.body).foregroundStyle(ServoMapColor.ink2).lineLimit(1)
                    }
                    Text(AccountLines.sync(account)).font(ServoMapFont.body(.footnote)).foregroundStyle(ServoMapColor.ink3)
                }
            }
            .padding(.top, ServoMapSpace.x4)
            PlainGroup(footer: "Deleting removes your account and everything stored with it. This iPhone keeps its own copy.", inset: 0) {
                Button { account.signOut() } label: {
                    PlainRow(title: "Sign out", chevron: false)
                }
                .buttonStyle(.plainRow)
                Button { confirmDelete = true } label: {
                    PlainRow(title: "Delete account", chevron: false, tint: ServoMapColor.priceExpensive)
                }
                .buttonStyle(.plainRow)
                .disabled(deleting)
            }
            if case .failed(let message) = account.status {
                Text(message).font(ServoMapFont.small).foregroundStyle(ServoMapColor.priceExpensive)
                    .padding(.top, ServoMapSpace.x3)
            }
        }
        .confirmationDialog("Delete your ServoMap account?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                deleting = true
                Task { _ = await account.deleteAccount(); deleting = false }
            }
        } message: {
            Text("Your saved stations, fill-ups, car and alert settings are removed from ServoMap's servers. This cannot be undone.")
        }
        // Signed out (or deleted), there is no account to show: back to Settings.
        .onChange(of: account.account == nil) { _, signedOut in if signedOut { dismiss() } }
        .sensoryFeedback(.success, trigger: account.account == nil) { _, signedOut in signedOut }
    }
}
