import Foundation
import Testing
@testable import Taktung

struct WidgetDeploymentTests {
    private func deployment(_ id: String, _ state: DeploymentState, _ timestamp: Double) -> VercelDeploymentSummary {
        VercelDeploymentSummary(id: id, name: "site", state: state, target: .preview,
                                createdAt: timestamp, meta: GitMeta(githubCommitMessage: "Not copied into widget"))
    }

    private func snapshot(_ deployments: [VercelDeploymentSummary] = []) -> WidgetDeploymentSnapshot {
        .make(projectID: "prj_site", projectName: "My site", accountID: "account", teamID: "team",
              revision: "one", source: .live, deployments: deployments, now: Date(timeIntervalSince1970: 50))
    }

    private func context() -> WidgetAccountContext {
        WidgetAccountContext(revision: "one", accountID: "account", teamID: "team", source: .live,
            projects: [.init(id: "prj_site", name: "My site")], cachedSnapshots: [snapshot()])
    }

    @Test func latestUsesCreationTimeRatherThanProductionTarget() {
        let value = snapshot([deployment("production", .ready, 1_000), deployment("preview", .building, 2_000)])
        #expect(value.latest?.id == "preview")
        #expect(value.latest?.state == .building)
        #expect(value.ready == 1 && value.building == 1 && value.total == 2)
    }

    @Test func statsBoundAndDeduplicateTheMostRecentTwenty() {
        var deployments = (1...25).map { deployment("id\($0)", .ready, Double($0) * 1_000) }
        deployments.append(deployments[24])
        let value = snapshot(deployments)
        #expect(value.total == 20 && value.ready == 20)
        #expect(value.latest?.id == "id25")
    }

    @Test func activityKeepsFiveNewestUniqueDeploysWithoutExtraMetadata() throws {
        var deployments = (1...9).map { deployment("id\($0)", .ready, Double($0) * 1_000) }
        deployments.append(deployments[8])
        let value = snapshot(deployments)
        #expect(value.events.map(\.id) == ["id9", "id8", "id7", "id6", "id5"])
        #expect(value.events.first == value.latest && value.isValid)
        let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        #expect(!encoded.contains("Not copied into widget"))
    }

    @Test func existingSmallAndMediumSnapshotsDecodeBeforeActivityWasAdded() throws {
        let value = snapshot([deployment("d", .ready, 1_000)])
        let data = try JSONEncoder().encode(value)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "events")
        let migrated = try JSONDecoder().decode(WidgetDeploymentSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(migrated.isValid && migrated.latest == value.latest && migrated.total == 1)
        #expect(migrated.events.isEmpty)
    }

    @Test func failureAndInFlightStatesMatchTheAppsDeploymentFilters() {
        let states: [DeploymentState] = [.ready, .error, .blocked, .canceled, .queued, .initializing, .building, .unknown, .deleted]
        let value = snapshot(states.enumerated().map { deployment("id\($0.offset)", $0.element, Double($0.offset + 1) * 1_000) })
        #expect(value.total == 9 && value.ready == 1 && value.failed == 3 && value.building == 3)
        #expect(value.latest?.state == .deleted)
    }

    @Test func emptyAndUnknownAreHonest() throws {
        let empty = snapshot()
        #expect(empty.isValid && empty.latest == nil && empty.total == 0)
        let payload = Data(#"{"deployments":[{"uid":"d","created":2000,"readyState":"FUTURE_STATE"}]}"#.utf8)
        let value = try WidgetDeploymentService.decode(payload, for: empty)
        #expect(value.latest?.state == .unknown && value.ready == 0)
        #expect(value.total == 1)
    }

    @Test func requestIsOneReadOnlyProjectScopedCall() throws {
        let request = WidgetDeploymentService.request(snapshot(), token: "test-credential")
        let url = try #require(request.url)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.host == "api.vercel.com" && url.path == "/v7/deployments")
        #expect(request.httpMethod == "GET" && request.httpBody == nil)
        #expect(query.contains(URLQueryItem(name: "projectId", value: "prj_site")))
        #expect(query.contains(URLQueryItem(name: "teamId", value: "team")))
        #expect(query.contains(URLQueryItem(name: "limit", value: "20")))
        #expect(request.timeoutInterval == 15)
    }

    @Test func allProjectsUsesOneWorkspaceCallAndAcceptsCrossProjectDeploys() throws {
        var all = snapshot(); all.projectID = WidgetAccountContext.allProjectsID; all.projectName = "All projects"
        let request = WidgetDeploymentService.request(all, token: "test-credential")
        let url = try #require(request.url)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(!query.contains { $0.name == "projectId" })
        #expect(query.contains(URLQueryItem(name: "teamId", value: "team")))
        let payload = Data(#"{"deployments":[{"uid":"one","projectId":"prj_one","name":"One","created":1000,"readyState":"READY"},{"uid":"two","projectId":"prj_two","name":"Two","created":2000,"readyState":"ERROR"}]}"#.utf8)
        let value = try WidgetDeploymentService.decode(payload, for: all)
        #expect(value.total == 2 && value.ready == 1 && value.failed == 1)
        #expect(value.latest?.projectName == "Two")
    }

    @Test func unknownProjectCannotBroadenAFilterToAll() {
        #expect(context().seed(for: "removed-project") == nil)
        #expect(context().seed(for: WidgetAccountContext.allProjectsID)?.projectName == "All projects")
    }

    @Test func mappingPrefersReadyStateAndRejectsWrongProject() throws {
        let payload = Data(#"{"deployments":[{"uid":"d","created":2000,"readyState":"ERROR","state":"READY","target":"production","meta":{"githubCommitMessage":"private message"},"env":{"SECRET":"not retained"}}]}"#.utf8)
        let value = try WidgetDeploymentService.decode(payload, for: snapshot())
        #expect(value.latest?.state == .error && value.failed == 1 && value.ready == 0)
        #expect(value.latest?.target == .production)
        let encoded = String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
        #expect(!encoded.contains("SECRET") && !encoded.contains("private message") && !encoded.contains("not retained"))
        let wrong = Data(#"{"deployments":[{"uid":"d","created":2000,"projectId":"another"}]}"#.utf8)
        #expect(throws: WidgetDeploymentService.Failure.self) { try WidgetDeploymentService.decode(wrong, for: snapshot()) }
    }

    @Test func staleScopeIsRetiredForAccountTeamSiteAndRevisionChanges() {
        let original = snapshot()
        for keyPath in [\WidgetDeploymentSnapshot.accountID, \.projectID, \.revision] {
            var other = original; other[keyPath: keyPath] = "changed"
            #expect(!original.isSameScope(as: other))
        }
        var other = original; other.teamID = nil
        #expect(!original.isSameScope(as: other))
        other = original; other.source = .demo
        #expect(!original.isSameScope(as: other))
    }

    @Test func keychainSummaryIsSeparateFromTokenAndDemoAndErasedOnDisconnect() throws {
        let keychain = KeychainStore(service: "widget-test-\(UUID())")
        defer { keychain.eraseAll() }
        try keychain.save("test-credential", key: KeychainStore.Key.accessToken)
        #expect(keychain.widgetStore.save(context()))
        #expect(keychain.widgetStore.load() == context())
        #expect(keychain.widgetStore.load(source: .demo) == nil)
        #expect(keychain.widgetStore.token() == "test-credential")
        keychain.eraseAll()
        #expect(keychain.widgetStore.load() == nil && keychain.widgetStore.token() == nil)
    }

    @Test func widgetCacheIsSeparatedByFilterAndScopeAndClearedWithCredentials() {
        let keychain = KeychainStore(service: "widget-cache-test-\(UUID())")
        defer { keychain.eraseAll() }
        let summary = snapshot([deployment("d", .ready, 1_000)])
        #expect(keychain.widgetStore.saveCache(summary))
        #expect(keychain.widgetStore.cachedSnapshot(for: context(), projectID: "prj_site") == summary)
        #expect(keychain.widgetStore.cachedSnapshot(for: context(), projectID: WidgetAccountContext.allProjectsID) == nil)
        var changed = context(); changed.revision = "another"
        #expect(keychain.widgetStore.cachedSnapshot(for: changed, projectID: "prj_site") == nil)
        keychain.eraseAll()
        #expect(keychain.widgetStore.cachedSnapshot(for: context(), projectID: "prj_site") == nil)
    }

    @MainActor @Test func sessionCatalogSurvivesAppSiteSelectionAndChangesWithTheWorkspace() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("widget-session-\(UUID())")
        let keychain = KeychainStore(service: "widget-session-\(UUID())")
        defer { keychain.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let session = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false,
                                 keychain: keychain, modelAvailability: { false }, clientFactory: { _ in DemoAPIClient() })
        _ = await session.connectWithToken("test-credential")
        let first = try #require(session.projects.first?.id)
        await session.selectProject(first)
        let old = try #require(keychain.widgetStore.load())
        #expect(old.projects.contains { $0.id == first } && old.source == .live)
        await session.selectProject(nil)
        #expect(keychain.widgetStore.load()?.name(for: first) != nil)
        await session.selectProject(first)
        let current = try #require(keychain.widgetStore.load())
        #expect(old.isSameScope(as: current))
        await session.selectTeam(nil)
        let newWorkspace = try #require(keychain.widgetStore.load())
        #expect(!old.isSameScope(as: newWorkspace) && newWorkspace.teamID == nil)
        await session.disconnect()
        #expect(keychain.widgetStore.load() == nil && keychain.widgetStore.token() == nil)
    }
}
