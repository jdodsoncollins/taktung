import Foundation
import Testing
@testable import Taktung

private actor SpotlightRecorder: SpotlightIndexing {
    private(set) var states: [SpotlightState] = []
    func apply(_ state: SpotlightState) async { states.append(state) }
}

struct SpotlightContentTests {
    private let scope = EvidenceScope(accountID: "uid_a", teamID: "team_a")
    private let project = buildDemoProjects().first { $0.id == DemoIDs.portfolio }!

    @Test func deploymentsCarryOnlySecretFreeMetadataAndStayBounded() {
        var list = buildDemoDeployments(projectId: DemoIDs.portfolio)
        list[0].meta.githubCommitMessage = "Rotate API_KEY=abc123secretvalue in config\n\nlonger body"
        list[1].meta.githubCommitMessage = "Add token vcp_abcdefghijklmnop1234"
        let items = SpotlightContent.deployments(list, project: project, scope: scope)
        #expect(items.count <= SpotlightContent.deploymentsPerSite)
        // Recognizable credentials are redacted; anything still secret-like is left out entirely.
        #expect(items.first { $0.id == list[1].id }?.title == "Add token [REDACTED]")
        list[2].meta.githubCommitMessage = "-----BEGIN PRIVATE KEY----- pasted by mistake"
        #expect(!SpotlightContent.deployments(list, project: project, scope: scope).contains { $0.id == list[2].id })
        let rotated = items.first { $0.id == list[0].id }
        #expect(rotated?.title.contains("abc123secretvalue") == false)
        #expect(rotated?.title.contains("longer body") == false)
        #expect(rotated?.shortSHA?.count ?? 0 <= 7)
        #expect(items.allSatisfy { $0.accountID == "uid_a" && $0.teamID == "team_a" && $0.projectID == DemoIDs.portfolio })
        #expect(SpotlightContent.deployments(list, project: project, scope: .demo).isEmpty)
        let subtitle = items.first?.subtitle ?? ""
        #expect(subtitle.hasPrefix(siteTitle(project)))
    }

    @Test func mergeReplacesOneSiteKeepsOthersAndDropsOtherScopes() {
        func record(_ id: String, project: ProjectID, account: String = "uid_a", minutes: Double) -> SpotlightDeployment {
            SpotlightDeployment(id: id, accountID: account, teamID: "team_a", projectID: project, siteName: project,
                                title: id, state: .ready, target: .production, branch: "main", shortSHA: "abc1234",
                                createdAt: Date(timeIntervalSince1970: minutes * 60))
        }
        let existing = [record("a1", project: "a", minutes: 1), record("b1", project: "b", minutes: 2),
                        record("x1", project: "b", account: "uid_other", minutes: 3)]
        let merged = SpotlightContent.merge(existing, replacing: "a", with: [record("a2", project: "a", minutes: 4)], scope: scope)
        #expect(merged.map(\.id) == ["a2", "b1"])
        let many = (0..<300).map { record("m\($0)", project: "m", minutes: Double($0)) }
        #expect(SpotlightContent.merge([], replacing: "m", with: many, scope: scope).count == SpotlightContent.maximumDeployments)
    }

    @Test func notesAreThePersonsOwnRedactedAndOpenOnlyInTheirScope() {
        let now = Date()
        let activity = [
            ActivityItem(id: "n1", kind: .note, title: "Note", detail: "Hero overlaps; API_KEY=abc123secretvalue", outcome: .info,
                         createdAt: now, projectId: DemoIDs.portfolio, deploymentId: nil, projectName: "example-portfolio.app"),
            ActivityItem(id: "d1", kind: .note, title: "Diagnose", detail: "Brief", outcome: .success, createdAt: now,
                         projectId: DemoIDs.portfolio, deploymentId: nil),
            ActivityItem(id: "c1", kind: .deploymentCompare, title: "Compared", detail: "Changed", outcome: .success, createdAt: now,
                         projectId: DemoIDs.portfolio, deploymentId: nil),
        ]
        let notes = SpotlightContent.notes(activity, scope: scope)
        #expect(notes.count == 1)
        #expect(notes.first?.text.contains("abc123secretvalue") == false)
        #expect(notes.first?.title == "Field Log note · example-portfolio.app")
        let identifier = notes.first?.id ?? ""
        #expect(SpotlightContent.noteItemID(identifier, scope: scope) == "n1")
        #expect(SpotlightContent.noteItemID(identifier, scope: EvidenceScope(accountID: "uid_a", teamID: "team_b")) == nil)
        #expect(SpotlightContent.noteItemID(identifier, scope: nil) == nil)
        #expect(SpotlightContent.notes(activity, scope: .demo).isEmpty)
    }

    @Test @MainActor func sessionIndexesOnlyWhatIsTurnedOnAndClearsOnDisconnect() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let keys = KeychainStore(service: "taktung.tests.\(UUID().uuidString)")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let recorder = SpotlightRecorder()
        var settings = SpotlightSettings(deployments: true, notes: true)
        let app = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { false }, spotlight: recorder, spotlightSettings: { settings },
                             clientFactory: { _ in DemoAPIClient() })
        _ = await app.connectWithToken("token")
        await app.selectProject(DemoIDs.portfolio)
        let scope = try #require(app.evidenceScope)
        _ = await app.addHistoryNote("Hero overlaps on small phones", scope: scope, projectID: DemoIDs.portfolio, deploymentID: nil)
        await app.syncSpotlight()
        var last = try #require(await recorder.states.last)
        #expect(last.scope == scope)
        guard case .replace(let projectID, let items) = last.deployments else { Issue.record("Expected deployments"); return }
        #expect(projectID == DemoIDs.portfolio)
        #expect(!items.isEmpty && items.count <= SpotlightContent.deploymentsPerSite)
        #expect(last.notes?.map(\.text) == ["Hero overlaps on small phones"])

        settings = SpotlightSettings(deployments: false, notes: false)
        await app.syncSpotlight()
        last = try #require(await recorder.states.last)
        if case .remove = last.deployments {} else { Issue.record("Expected deployments to be removed") }
        #expect(last.notes == nil)

        settings = SpotlightSettings(deployments: true, notes: true)
        await app.disconnect()
        for _ in 0..<500 { if await recorder.states.last?.scope == nil { break }; await Task.yield() }
        #expect(await recorder.states.last?.scope == nil)
        let revisions = await recorder.states.map(\.revision)
        #expect(revisions == revisions.sorted())
    }

    @Test @MainActor func demoNeverIndexes() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let keys = KeychainStore(service: "taktung.tests.\(UUID().uuidString)")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let recorder = SpotlightRecorder()
        let demo = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: true, keychain: keys,
                              spotlight: recorder, spotlightSettings: { SpotlightSettings(deployments: true, notes: true) })
        await demo.bootstrap()
        await demo.syncSpotlight()
        let states = await recorder.states
        #expect(!states.isEmpty)
        #expect(states.allSatisfy { $0.scope == nil && $0.notes == nil })
    }
}
