import Foundation

/** Signed-in calls to /api/v1/auth and /api/v1/me. */
struct AccountAPI: Sendable {
    enum Failure: Error, Equatable { case unauthenticated, rejected(Int), offline }

    private struct Envelope<T: Decodable>: Decodable { let data: T }

    let token: String?

    func signIn(provider: String, identityToken: String, name: String?) async throws -> SessionDTO {
        struct Body: Encodable { let identityToken: String; let name: String? }
        return try await send("POST", "auth/\(provider)", Body(identityToken: identityToken, name: name))
    }

    func me() async throws -> MeDTO { try await send("GET", "me", Optional<Int>.none) }
    func deleteAccount() async throws { try await sendEmpty("DELETE", "me", Optional<Int>.none) }

    func putSaved(_ ids: [String]) async throws {
        struct Body: Encodable { let stationIds: [String] }
        try await sendEmpty("PUT", "me/saved", Body(stationIds: ids))
    }

    func putFillUps(_ fills: [FillUpDTO]) async throws {
        struct Body: Encodable { let fillUps: [FillUpDTO] }
        guard !fills.isEmpty else { return }
        try await sendEmpty("PUT", "me/fillups", Body(fillUps: fills))
    }

    func deleteFillUp(_ id: String) async throws { try await sendEmpty("DELETE", "me/fillups/\(id)", Optional<Int>.none) }
    func putCar(_ car: CarDTO) async throws { try await sendEmpty("PUT", "me/car", car) }
    func putAlerts(_ alerts: AlertsDTO) async throws { try await sendEmpty("PUT", "me/alerts", alerts) }

    func putDevice(_ token: String, environment: String) async throws {
        struct Body: Encodable { let environment: String }
        try await sendEmpty("PUT", "me/devices/\(token)", Body(environment: environment))
    }

    // MARK: Transport

    private func request(_ method: String, _ path: String, _ body: (some Encodable)?) throws -> URLRequest {
        var r = URLRequest(url: API.base.appending(path: path))
        r.httpMethod = method
        r.timeoutInterval = 20
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONEncoder().encode(body)
        }
        return r
    }

    private func perform(_ r: URLRequest) async throws -> Data {
        let data: Data, response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: r) } catch { throw Failure.offline }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw Failure.unauthenticated }
        guard (200..<300).contains(status) else { throw Failure.rejected(status) }
        return data
    }

    private func send<T: Decodable>(_ method: String, _ path: String, _ body: (some Encodable)?) async throws -> T {
        let data = try await perform(try request(method, path, body))
        return try JSONDecoder().decode(Envelope<T>.self, from: data).data
    }

    private func sendEmpty(_ method: String, _ path: String, _ body: (some Encodable)?) async throws {
        _ = try await perform(try request(method, path, body))
    }
}
