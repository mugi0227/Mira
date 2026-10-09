import Foundation
import Security

// PERSONAL BUILD ONLY — remove before submitting to the App Store.
// The Gemini key is typed in by the owner and kept in this device's Keychain;
// a distributed build must call Gemini through a server instead, so that no
// provider credential ever ships with or is entered into the app.
final class GeminiSettingsStore: @unchecked Sendable {
    static let shared = GeminiSettingsStore()
    static let defaultModel = "gemini-3.8-flash"

    private let defaults: UserDefaults
    private let service = "jp.mugi.mira.gemini"
    private let account = "api-key"
    private let modelKey = "mira.gemini.model"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var model: String {
        let stored = defaults.string(forKey: modelKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? Self.defaultModel : stored
    }

    var hasKey: Bool { apiKey() != nil }

    func setModel(_ value: String) {
        defaults.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelKey)
    }

    func apiKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    @discardableResult
    func saveKey(_ rawKey: String) -> Bool {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (20...200).contains(key.count), key.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }) else { return false }
        let data = Data(key.utf8)
        var status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = baseQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        return status == errSecSuccess
    }

    func removeKey() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
