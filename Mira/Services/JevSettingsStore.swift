import Foundation
import Security

/// UserDefaults and the Keychain are thread-safe. Provider credentials never live here;
/// this Keychain item contains only a token for the user's Mira backend.
final class JevSettingsStore: JevConfigurationProviding, @unchecked Sendable {
    static let shared = JevSettingsStore()
    private let defaults: UserDefaults
    private let service = "jp.mugi.mira.jev-backend"
    private let enabledKey = "mira.jev.enabled"
    private let endpointKey = "mira.jev.endpoint"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var isEnabled: Bool { defaults.bool(forKey: enabledKey) }
    var endpointText: String { defaults.string(forKey: endpointKey) ?? "" }

    func setEnabled(_ enabled: Bool) { defaults.set(enabled, forKey: enabledKey) }

    func configuration() -> JevConfiguration? {
        let storedEndpoint = endpointText
        guard isEnabled, let endpoint = JevConfiguration.endpoint(from: storedEndpoint),
              let token = token(for: storedEndpoint), JevConfiguration.validToken(token) else { return nil }
        return JevConfiguration(endpoint: endpoint, clientToken: token)
    }

    func token(for endpoint: String) -> String? {
        var query = keychainQuery(endpoint: endpoint)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func save(endpointText: String, token: String, enabled: Bool) -> Bool {
        guard let endpoint = JevConfiguration.endpoint(from: endpointText),
              JevConfiguration.validToken(token) else { return false }
        let endpointValue = endpoint.absoluteString
        let query = keychainQuery(endpoint: endpointValue)
        let update = [kSecValueData as String: Data(token.utf8)]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(token.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { return false }
        let previousEndpoint = self.endpointText
        // Disable before replacing configuration so a mixed host/token cannot be observed.
        setEnabled(false)
        defaults.set(endpointValue, forKey: endpointKey)
        if !previousEndpoint.isEmpty && previousEndpoint != endpointValue {
            SecItemDelete(keychainQuery(endpoint: previousEndpoint) as CFDictionary)
        }
        setEnabled(enabled)
        return true
    }

    func removeConfiguration() {
        setEnabled(false)
        SecItemDelete(keychainQuery(endpoint: endpointText) as CFDictionary)
        defaults.removeObject(forKey: endpointKey)
    }

    private func keychainQuery(endpoint: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: endpoint]
    }
}
