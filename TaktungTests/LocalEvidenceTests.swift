import Foundation
import Testing
@testable import Taktung

struct LocalEvidenceTests {
    @Test @MainActor func retryingTheSameNoteAfterStorageRecoveryDoesNotDuplicateIt() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("blocked directory".utf8).write(to: root)
        let app = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false)
        let scope = EvidenceScope(accountID: "account", teamID: nil)
        await app.restoreHistory(scope: scope)
        #expect(!(await app.addHistoryNote("Review the hero", scope: scope, projectID: nil, deploymentID: nil, noteID: "same-note")))
        try FileManager.default.removeItem(at: root)
        #expect(await app.addHistoryNote("Review the hero on mobile", scope: scope, projectID: nil, deploymentID: nil, noteID: "same-note"))
        #expect(app.recentActivity.count == 1)
        let saved = try await LocalEvidenceStore(root: root).loadHistory(scope: scope)
        #expect(saved?.count == 1)
        #expect(saved?.first?.detail == "Review the hero on mobile")
    }

    private func item(_ id: String, time: TimeInterval = 1, detail: String = "Checked homepage") -> ActivityItem {
        ActivityItem(id: id, kind: .note, title: "Review", detail: detail, outcome: .info,
                     createdAt: Date(timeIntervalSince1970: time), projectId: "project", deploymentId: "deploy")
    }

    @Test func survivesReopeningAndSeparatesAccountsTeamsAndDemo() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = EvidenceScope(accountID: "account", teamID: "team")
        let store = LocalEvidenceStore(root: root)
        try await store.append(item("first"), scope: scope)
        let reopened = LocalEvidenceStore(root: root)
        #expect(try await reopened.loadHistory(scope: scope)?.map(\.id) == ["first"])
        #expect(try await reopened.loadHistory(scope: EvidenceScope(accountID: "other", teamID: "team")) == nil)
        #expect(try await reopened.loadHistory(scope: EvidenceScope(accountID: "account", teamID: nil)) == nil)
        #expect(try await reopened.loadHistory(scope: .demo) == nil)
    }

    @Test func retentionKeepsNewestAndClearingDoesNotResurrectOnRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalEvidenceStore(root: root)
        let scope = EvidenceScope(accountID: "account", teamID: nil)
        let items = (0..<1_000).reversed().map { item(String($0), time: Double($0)) }
        try await store.replaceHistory(items, scope: scope)
        try await store.append(item("newest", time: 2_000), scope: scope)
        let retained = try await store.loadHistory(scope: scope)!
        #expect(retained.count == 1_000)
        #expect(retained.first?.id == "newest")
        #expect(!retained.contains { $0.id == "0" })
        try await store.replaceHistory([], scope: scope)
        #expect(try await LocalEvidenceStore(root: root).loadHistory(scope: scope) == [])
    }

    @Test func credentialsAreRedactedOnDiskAndExport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalEvidenceStore(root: root)
        let scope = EvidenceScope(accountID: "account", teamID: nil)
        let value = item("sensitive", detail: "API_KEY=do-not-store Bearer pretend-credential")
        try await store.append(value, scope: scope)
        let persisted = try await store.loadHistory(scope: scope)!
        #expect(!persisted[0].detail.contains("do-not-store"))
        #expect(!persisted[0].detail.contains("pretend-credential"))
        #expect(!historyExport([value]).contains("do-not-store"))
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        for case let file as URL in files.allObjects where file.pathExtension == "json" {
            #expect(!(try String(contentsOf: file, encoding: .utf8)).contains("do-not-store"))
        }
    }

    @Test func baselineSurvivesRestartIsScopedAndIsKeptWhenHistoryClears() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalEvidenceStore(root: root)
        let scope = EvidenceScope(accountID: "account", teamID: nil)
        let capture = VisualCapture(projectID: "project", deploymentID: "deploy", deploymentTitle: "Landing page",
                                    commit: "abc1234", route: "/", capturedAt: .now, png: Data([1, 2, 3]))
        try await store.saveBaseline(capture, scope: scope)
        try await store.replaceHistory([], scope: scope)
        let reopened = LocalEvidenceStore(root: root)
        #expect(try await reopened.loadBaseline(scope: scope, projectID: "project", route: "/")?.id == capture.id)
        #expect(try await reopened.loadBaseline(scope: scope, projectID: "other", route: "/") == nil)
        #expect(try await reopened.loadBaseline(scope: scope, projectID: "project", route: "/about") == nil)
        #expect(try await reopened.loadBaseline(scope: .demo, projectID: "project", route: "/") == nil)
        try await store.eraseAccount(scope: scope)
        #expect(try await reopened.loadBaseline(scope: scope, projectID: "project", route: "/") == nil)
    }

    @Test func corruptedHistoryIsPreservedRatherThanOverwritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalEvidenceStore(root: root)
        let scope = EvidenceScope(accountID: "account", teamID: nil)
        try await store.append(item("first"), scope: scope)
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        let file = (files.allObjects as! [URL]).first { $0.lastPathComponent == "history.json" }!
        try Data("broken evidence".utf8).write(to: file)
        await #expect(throws: VisualComparisonError.self) { try await store.append(item("second"), scope: scope) }
        #expect(try String(contentsOf: file, encoding: .utf8) == "broken evidence")
    }

    @Test @MainActor func sessionRestoresNotesAndRejectsAScopeChange() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let scope = EvidenceScope(accountID: "account", teamID: nil)
        let session = AppSession(evidenceStore: LocalEvidenceStore(root: root))
        await session.restoreHistory(scope: scope)
        #expect(await session.addHistoryNote("Homepage reviewed", scope: scope, projectID: nil, deploymentID: nil))
        let reopened = AppSession(evidenceStore: LocalEvidenceStore(root: root))
        await reopened.restoreHistory(scope: scope)
        #expect(reopened.recentActivity.first?.detail == "Homepage reviewed")
        let other = EvidenceScope(accountID: "other", teamID: nil)
        await reopened.restoreHistory(scope: other)
        #expect(await reopened.addHistoryNote("Other account", scope: other, projectID: nil, deploymentID: nil))
        await reopened.clearActivity(expectedScope: scope)
        #expect(reopened.recentActivity.first?.detail == "Other account")
        #expect(!(await reopened.addHistoryNote("Wrong account", scope: scope, projectID: nil, deploymentID: nil)))
        #expect(reopened.recentActivity.count == 1)
        await session.clearActivity()
        await session.restoreHistory(scope: scope)
        #expect(session.recentActivity.isEmpty)
    }

    @Test func baselinesAreBoundedByCaptureDate() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalEvidenceStore(root: root)
        for index in 0..<21 {
            let capture = VisualCapture(projectID: "project", deploymentID: "deploy", deploymentTitle: "Page",
                                        commit: "abc1234", route: "/page-\(index)",
                                        capturedAt: Date(timeIntervalSince1970: Double(index)), png: Data([1, 2, 3]))
            try await store.saveBaseline(capture, scope: .demo)
        }
        #expect(try await store.loadBaseline(scope: .demo, projectID: "project", route: "/page-0") == nil)
        #expect(try await store.loadBaseline(scope: .demo, projectID: "project", route: "/page-20") != nil)
    }

    @Test @MainActor func nextSuccessfulWriteRetriesUnsavedNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("blocked directory".utf8).write(to: root)
        let store = LocalEvidenceStore(root: root)
        let app = AppSession(evidenceStore: store, demoMode: false)
        let scope = EvidenceScope(accountID: "account", teamID: "team")
        await app.restoreHistory(scope: scope)
        #expect(!(await app.addHistoryNote("Unsaved first note", scope: scope, projectID: nil, deploymentID: nil)))
        #expect(app.historyStorageError != nil)
        try FileManager.default.removeItem(at: root)
        #expect(await app.addHistoryNote("Second note", scope: scope, projectID: nil, deploymentID: nil))
        let restored = try await LocalEvidenceStore(root: root).loadHistory(scope: scope)
        #expect(Set(restored?.map(\.detail) ?? []) == ["Unsaved first note", "Second note"])
        #expect(app.historyStorageError == nil)
    }

    @Test @MainActor func failedClearKeepsHistoryVisibleAndCanBeRetried() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let backup = root.appendingPathExtension("backup")
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: backup) }
        let store = LocalEvidenceStore(root: root)
        let app = AppSession(evidenceStore: store, demoMode: false)
        let scope = EvidenceScope(accountID: "account", teamID: "team")
        await app.restoreHistory(scope: scope)
        #expect(await app.addHistoryNote("Keep this if clearing fails", scope: scope, projectID: nil, deploymentID: nil))
        try FileManager.default.moveItem(at: root, to: backup)
        try Data("blocked directory".utf8).write(to: root)
        await app.clearActivity()
        #expect(app.recentActivity.contains { $0.detail == "Keep this if clearing fails" })
        #expect(app.historyStorageError != nil)
        try FileManager.default.removeItem(at: root)
        try FileManager.default.moveItem(at: backup, to: root)
        await app.clearActivity()
        #expect(app.recentActivity.isEmpty)
        #expect(try await store.loadHistory(scope: scope)?.isEmpty == true)
    }
}
