import AuthenticationServices
import CryptoKit
import Foundation

/**
 * Google sign-in without Google's SDK: OAuth 2 authorisation code with PKCE in the system web
 * sheet, as Google documents for installed apps, exchanged for an ID token the Worker verifies.
 * The iOS client id comes from the build setting GOOGLE_IOS_CLIENT_ID (Info.plist
 * ServoMapGoogleClientID); without it the Google button is hidden.
 */
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    enum Failure: Error { case notConfigured, cancelled, failed }

    static var clientID: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "ServoMapGoogleClientID") as? String
        return (value?.isEmpty == false && value?.contains("$(") == false) ? value : nil
    }

    private var session: ASWebAuthenticationSession?

    /** Returns Google's ID token for the chosen account. */
    func signIn() async throws -> String {
        guard let clientID = Self.clientID else { throw Failure.notConfigured }
        // Installed-app redirect: the client id reversed, as the URL scheme.
        let scheme = clientID.split(separator: ".").reversed().joined(separator: ".")
        let redirect = "\(scheme):/oauth2redirect"
        let verifier = Self.randomURLSafe(32)
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
        var auth = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        auth.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]
        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: auth.url!, callback: .customScheme(scheme)) { url, error in
                if let url { cont.resume(returning: url) }
                else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { cont.resume(throwing: Failure.cancelled) }
                else { cont.resume(throwing: Failure.failed) }
            }
            s.presentationContextProvider = self
            s.prefersEphemeralWebBrowserSession = false
            session = s
            s.start()
        }
        guard let code = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw Failure.failed
        }
        var token = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        token.httpMethod = "POST"
        token.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            .init(name: "code", value: code), .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirect), .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code_verifier", value: verifier),
        ]
        token.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: token)
        struct Reply: Decodable { let id_token: String? }
        guard let idToken = try JSONDecoder().decode(Reply.self, from: data).id_token else { throw Failure.failed }
        return idToken
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
        }
    }

    private static func randomURLSafe(_ bytes: Int) -> String {
        var data = Data(count: bytes)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
        return data.base64URL
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
