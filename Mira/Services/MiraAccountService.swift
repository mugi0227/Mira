import Foundation
import Security

/// What the import server says about the signed-in person.
struct MiraAccount: Codable, Hashable, Sendable {
    var userId: String
    var premium: Bool
    var profile: String

    var colorProfile: ColorProfile { ColorProfile(rawValue: profile) ?? .standard }
}

enum MiraAccountError: LocalizedError {
    case noServer
    case notSignedIn
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .noServer: "サーバーのURLが設定されていません。"
        case .notSignedIn: "もう一度Appleでサインインしてください。"
        case .server(let status, let message): "サーバーエラー（\(status)）：\(message)"
        }
    }
}

/// Talks to the Mira import server. Only a session token issued by our own
/// server is kept on the device, never a provider key.
final class MiraAccountService: @unchecked Sendable {
    static let shared = MiraAccountService()

    private let defaults: UserDefaults
    private let session: URLSession
    private let serverKey = "mira.account.server"
    private let keychainService = "jp.mugi.mira.session"

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
    }

    var serverText: String {
        get { defaults.string(forKey: serverKey) ?? (Bundle.main.object(forInfoDictionaryKey: "MiraServerURL") as? String ?? "") }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: serverKey) }
    }

    var serverURL: URL? {
        guard let components = URLComponents(string: serverText), components.scheme == "https", components.host != nil else { return nil }
        return components.url
    }

    var isSignedIn: Bool { sessionToken() != nil }

    func signIn(identityToken: String) async throws -> MiraAccount {
        struct Response: Decodable { var sessionToken: String; var account: MiraAccount }
        let response: Response = try await send("v1/session", method: "POST", body: ["identityToken": identityToken], authorized: false)
        saveSessionToken(response.sessionToken)
        return response.account
    }

    func refreshAccount() async throws -> MiraAccount {
        struct Response: Decodable { var account: MiraAccount }
        let response: Response = try await send("v1/account", method: "GET", body: nil, authorized: true)
        return response.account
    }

    func readCalendar(image: Data, today: String) async throws -> ExtractedCalendarPage {
        try await send("v1/calendar-import", method: "POST",
            body: ["imageBase64": image.base64EncodedString(), "mimeType": "image/jpeg", "today": today],
            authorized: true, timeout: 120)
    }

    func signOut() {
        SecItemDelete(keychainQuery as CFDictionary)
    }

    private func send<Response: Decodable>(
        _ path: String,
        method: String,
        body: [String: String]?,
        authorized: Bool,
        timeout: TimeInterval = 30
    ) async throws -> Response {
        guard let base = serverURL else { throw MiraAccountError.noServer }
        var request = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized {
            guard let token = sessionToken() else { throw MiraAccountError.notSignedIn }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { request.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            if status == 401 { signOut(); throw MiraAccountError.notSignedIn }
            struct Failure: Decodable { var error: String? }
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.error ?? "不明なエラー"
            throw MiraAccountError.server(status, message)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: "session"]
    }

    private func sessionToken() -> String? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveSessionToken(_ token: String) {
        let data = Data(token.utf8)
        var status = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
    }
}

/// Reads calendar images through the Mira server (premium accounts).
struct ServerCalendarExtractor: Sendable {
    var service: MiraAccountService = .shared

    func extract(image: Data, sourceIndex: Int, today: Date) async throws -> [ImportCandidate] {
        let todayText = DateFormatter.mira("yyyy-MM-dd", locale: Locale(identifier: "en_US_POSIX")).string(from: today)
        let page = try await service.readCalendar(image: image, today: todayText)
        return ImportCandidateBuilder.candidates(from: page, sourceIndex: sourceIndex)
    }
}
