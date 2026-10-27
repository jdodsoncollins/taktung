import Foundation
import Security

enum TokenSource: String, Sendable {
    case pat
    case oauth
}

struct KeychainStore: Sendable {
    private let service: String

    init(service: String = AppConfig.bundleID) { self.service = service }

    enum Key {
        static let accessToken = AppConfig.accessTokenKey
        static let tokenSource = "vercel.token-source"
        static let selectedTeamId = "vercel.selected-team"
        static let selectedProjectId = "vercel.selected-project"
        static let evidenceUserID = "vercel.evidence-user"
    }

    static let personalTeamSelection = "__taktung_personal__"

    var widgetStore: WidgetSnapshotStore { WidgetSnapshotStore(service: service) }

    func selectedTeamID() -> TeamID? {
        let value = load(Key.selectedTeamId)
        return value == Self.personalTeamSelection ? nil : value
    }

    func saveTeamSelection(_ id: TeamID?) throws {
        try save(id ?? Self.personalTeamSelection, key: Key.selectedTeamId)
    }

    func save(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
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
        [Key.accessToken, Key.tokenSource, Key.selectedTeamId, Key.selectedProjectId, Key.evidenceUserID].forEach(delete)
        widgetStore.clear()
    }
}
