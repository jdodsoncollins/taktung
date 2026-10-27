import Foundation
import Security

/// The extension joins the app's existing, device-only Keychain access group.
/// No credential copies, App Group preferences, or shared plaintext files are created.
struct WidgetSnapshotStore: Sendable {
    var service: String = AppConfig.bundleID

    func load(source: WidgetDeploymentSnapshot.Source = .live) -> WidgetAccountContext? {
        guard let data = read(key(for: source)), data.count <= 131_072,
              let value = try? JSONDecoder().decode(WidgetAccountContext.self, from: data),
              value.isValid, value.source == source else { return nil }
        return value
    }

    @discardableResult
    func save(_ context: WidgetAccountContext) -> Bool {
        guard context.isValid, let data = try? JSONEncoder().encode(context), data.count <= 131_072 else { return false }
        return write(data, key: key(for: context.source))
    }

    func cachedSnapshot(for context: WidgetAccountContext, projectID: String) -> WidgetDeploymentSnapshot? {
        guard context.source == .live, let seed = context.seed(for: projectID),
              let data = cacheStore.read(cacheKey(revision: context.revision, projectID: projectID)), data.count <= 8_192,
              let snapshot = try? JSONDecoder().decode(WidgetDeploymentSnapshot.self, from: data),
              snapshot.isValid, snapshot.isSameScope(as: seed) else { return nil }
        return snapshot
    }

    @discardableResult
    func saveCache(_ snapshot: WidgetDeploymentSnapshot) -> Bool {
        guard snapshot.source == .live, snapshot.isValid,
              let data = try? JSONEncoder().encode(snapshot), data.count <= 8_192 else { return false }
        // Separate per account/team revision and filter; the extension cannot write host context.
        return cacheStore.write(data, key: cacheKey(revision: snapshot.revision, projectID: snapshot.projectID))
    }

    private var cacheStore: Self { Self(service: service + ".widget-cache") }

    private func cacheKey(revision: String, projectID: String) -> String { "\(revision)|\(projectID)" }

    private func write(_ data: Data, key: String) -> Bool {
        let query = query(key)
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            return SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    func token() -> String? {
        read(AppConfig.accessTokenKey).flatMap { String(data: $0, encoding: .utf8) }
    }

    func clear(source: WidgetDeploymentSnapshot.Source? = nil) {
        for source in source.map({ [$0] }) ?? [WidgetDeploymentSnapshot.Source.live, .demo] {
            SecItemDelete(query(key(for: source)) as CFDictionary)
        }
        if source != .demo {
            SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                           kSecAttrService as String: service + ".widget-cache"] as CFDictionary)
        }
    }

    private func key(for source: WidgetDeploymentSnapshot.Source) -> String {
        source == .live ? AppConfig.widgetSnapshotKey : AppConfig.demoWidgetSnapshotKey
    }

    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    private func read(_ key: String) -> Data? {
        var query = query(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
}
