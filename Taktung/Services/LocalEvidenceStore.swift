import Foundation
import CryptoKit

/// Serial, atomic storage. Live accounts/teams and demo never share a directory.
actor LocalEvidenceStore {
    static let historyLimit = 1_000
    private let root: URL
    private let manager = FileManager.default

    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("TaktungEvidence", isDirectory: true)) {
        self.root = root
    }

    private struct History: Codable {
        var version = 1
        var items: [ActivityItem]
    }

    private struct Baseline: Codable {
        var version = 1
        var capture: VisualCapture
    }

    func loadHistory(scope: EvidenceScope) throws -> [ActivityItem]? {
        let url = directory(scope).appendingPathComponent("history.json")
        guard manager.fileExists(atPath: url.path) else { return nil }
        guard let history = try? JSONDecoder().decode(History.self, from: Data(contentsOf: url)), history.version == 1 else {
            throw VisualComparisonError.corruptStore
        }
        return history.items.prefix(Self.historyLimit).map(sanitizedActivity)
    }

    func append(_ item: ActivityItem, scope: EvidenceScope) throws {
        try append([item], scope: scope)
    }

    /// Merge the bounded in-memory journal too, so the next successful write retries earlier failures.
    func append(_ pending: [ActivityItem], scope: EvidenceScope) throws {
        var items = try loadHistory(scope: scope) ?? []
        let pendingIDs = Set(pending.map(\.id))
        items.removeAll { pendingIDs.contains($0.id) }
        items.append(contentsOf: pending.map(sanitizedActivity))
        items.sort { $0.createdAt > $1.createdAt }
        try write(History(items: Array(items.prefix(Self.historyLimit))), to: directory(scope).appendingPathComponent("history.json"))
    }

    func replaceHistory(_ items: [ActivityItem], scope: EvidenceScope) throws {
        try write(History(items: Array(items.prefix(Self.historyLimit)).map(sanitizedActivity)),
                  to: directory(scope).appendingPathComponent("history.json"))
    }

    func loadBaseline(scope: EvidenceScope, projectID: ProjectID, route: String) throws -> VisualCapture? {
        let url = baselineURL(scope: scope, projectID: projectID, route: route)
        guard manager.fileExists(atPath: url.path) else { return nil }
        guard let baseline = try? JSONDecoder().decode(Baseline.self, from: Data(contentsOf: url)),
              baseline.version == 1, baseline.capture.projectID == projectID, baseline.capture.route == route else {
            throw VisualComparisonError.corruptStore
        }
        return baseline.capture
    }

    func saveBaseline(_ capture: VisualCapture, scope: EvidenceScope) throws {
        guard capture.png.count <= 8_000_000, !capture.png.isEmpty,
              capture.route == (try comparisonRoute(capture.route)),
              capture.viewportWidth == 390, capture.viewportHeight == 844 else {
            throw VisualComparisonError.invalidImage
        }
        try write(Baseline(capture: capture), to: baselineURL(scope: scope, projectID: capture.projectID, route: capture.route))
        let files = try manager.contentsOfDirectory(at: directory(scope), includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("visual-") }
        // Bound disk use to twenty route baselines per team. Dates come from our records, not file timestamps.
        if files.count > 20 {
            let dated = files.compactMap { url -> (URL, Date)? in
                guard let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Baseline.self, from: data) else { return nil }
                return (url, value.capture.capturedAt)
            }.sorted { $0.1 > $1.1 }
            for (url, _) in dated.dropFirst(20) { try manager.removeItem(at: url) }
        }
    }

    func eraseAccount(scope: EvidenceScope) throws {
        let url = accountDirectory(scope)
        if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
    }

    private func baselineURL(scope: EvidenceScope, projectID: String, route: String) -> URL {
        directory(scope).appendingPathComponent("visual-\(digest(projectID + "\n" + route)).json")
    }

    private func accountDirectory(_ scope: EvidenceScope) -> URL {
        root.appendingPathComponent(scope.isDemo ? "demo" : "account-\(digest(scope.accountID))", isDirectory: true)
    }

    private func directory(_ scope: EvidenceScope) -> URL {
        accountDirectory(scope).appendingPathComponent("team-\(digest(scope.teamID ?? "personal"))", isDirectory: true)
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func write<T: Encodable>(_ value: T, to destination: URL) throws {
        let folder = destination.deletingLastPathComponent()
        try manager.createDirectory(at: folder, withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.complete])
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var protectedRoot = root
        try protectedRoot.setResourceValues(excluded)
        try JSONEncoder().encode(value).write(to: destination, options: [.atomic, .completeFileProtection])
    }
}
