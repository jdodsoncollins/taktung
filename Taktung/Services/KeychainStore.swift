import Foundation
import Security

enum TokenSource: String, Sendable {
    case pat
    case oauth
}

struct KeychainStore: Sendable {
    private let service = AppConfig.bundleID

    enum Key {
        static let accessToken = "vercel.access-token"
        static let tokenSource = "vercel.token-source"
        static let selectedTeamId = "vercel.selected-team"
        static let selectedProjectId = "vercel.selected-project"
    }

    func save(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VercelAPIError(status: Int(status), detail: "Keychain save failed (\(status))")
        }
    }

    func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    func eraseAll() {
        [Key.accessToken, Key.tokenSource, Key.selectedTeamId, Key.selectedProjectId].forEach(delete)
    }
}
