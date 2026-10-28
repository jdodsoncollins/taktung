import Foundation
import Testing
@testable import Taktung

private actor DeploymentGate {
    private var entered = false
    private var waiting: CheckedContinuation<Void, Never>?
    private var observers: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        await withCheckedContinuation { continuation in
            waiting = continuation
            entered = true
            observers.forEach { $0.resume() }
            observers = []
        }
    }
    func untilEntered() async {
        if entered { return }
        await withCheckedContinuation { observers.append($0) }
    }
    func open() { waiting?.resume(); waiting = nil }
}

private struct SessionTestAPI: VercelAPIClient {
    var account: String
    var projectsFail = false
    var userFail = false
    var logsFail = false
    var gate: DeploymentGate?
    var projectsGate: DeploymentGate?
    var deploymentsGate: DeploymentGate?
    var inspectionGate: DeploymentGate?
    var teams: [VercelTeam] = []
    func getUser() async throws -> VercelUser {
        if userFail { throw VercelAPIError(status: 401, detail: "Synthetic rejected session") }
        return VercelUser(id: account, username: account)
    }
    func inspect(_ tool: ProjectTool, projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID?) async throws -> InspectionResult {
        if let inspectionGate { await inspectionGate.wait() }
        return .init(rows: [], note: "Synthetic scoped result", emptyTitle: "No records")
    }
    func analyticsOverview(projectID: ProjectID, teamID: TeamID?, window: AnalyticsWindow) async throws -> AnalyticsOverview {
        if let inspectionGate { await inspectionGate.wait() }
        return .init(window: window, counts: .init(visitors: 0, pageviews: 0), days: [])
    }
    func analyticsSegments(projectID: ProjectID, teamID: TeamID?, dimension: AnalyticsDimension, window: AnalyticsWindow) async throws -> [AnalyticsSegment] {
        if let inspectionGate { await inspectionGate.wait() }
        return []
    }
    func listTeams() async throws -> [VercelTeam] { teams }
    func listProjects(teamId: TeamID?) async throws -> [VercelProject] {
        if let projectsGate { await projectsGate.wait() }
        if projectsFail { throw VercelAPIError(status: 503, detail: "Synthetic projects failure") }
        return [project("one"), project("two")]
    }
    func project(_ suffix: String) -> VercelProject {
        VercelProject(id: "\(account)-\(suffix)", name: suffix, productionDeployment: deployment("\(account)-\(suffix)"),
                      needsAttention: false, attentionReason: .none)
    }
    func deployment(_ project: String) -> VercelDeploymentSummary {
        VercelDeploymentSummary(id: "\(project)-deploy", url: "test.vercel.app", name: project, state: .ready, createdAt: 1,
                               meta: GitMeta(githubCommitMessage: "Synthetic build"))
    }
    func listDeployments(projectId: String, teamId: String?, limit: Int) async throws -> [VercelDeploymentSummary] {
        if let deploymentsGate { await deploymentsGate.wait() }
        return [deployment(projectId)]
    }
    func searchDeployments(projectId: ProjectID, teamId: TeamID?, query: DeploymentQuery) async throws -> [VercelDeploymentSummary] {
        var older = deployment(projectId)
        older.id = "\(projectId)-older"
        return [deployment(projectId), older].filter { query.matches($0, now: Date(timeIntervalSince1970: 10)) }
    }
    func getDeployment(id: String, teamId: String?) async throws -> VercelDeploymentSummary {
        if let gate { await gate.wait() }
        var value = deployment("\(account)-one")
        value.id = id
        return value
    }
    func getBuildLogLines(id: String, teamId: String?, limit: Int) async throws -> [BuildLogLine] {
        if logsFail { throw VercelAPIError(status: 503, detail: "Synthetic log failure") }
        return []
    }
    func listEnvVarMeta(projectId: String, teamId: String?) async throws -> [EnvVarMeta] { [] }
    func redeploy(deploymentId: String, projectId: String, teamId: String?, target: DeploymentTarget?) async throws -> VercelDeploymentSummary { throw VercelAPIError(status: 400, detail: "Tests cannot mutate") }
    func promote(deploymentId: String, projectId: String, teamId: String?) async throws { throw VercelAPIError(status: 400, detail: "Tests cannot mutate") }
    func rollback(deploymentId: String, projectId: String, teamId: String?) async throws { throw VercelAPIError(status: 400, detail: "Tests cannot mutate") }
    func productionDeploymentID(projectId: String, teamId: String?) async throws -> String? { deployment(projectId).id }
}

private actor SearchPlannerCalls {
    private(set) var queries: [String] = []
    func record(_ query: String) { queries.append(query) }
}

@Suite(.serialized)
struct SessionQualityTests {
    @Test @MainActor func projectChangesDiscardPendingInspectionAndOldScopesCannotRestart() async throws {
        let root = newRoot, keys = newKeychain, gate = DeploymentGate()
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0, inspectionGate: gate) }
        _ = await app.connectWithToken("A")
        await app.selectProject("A-one")
        let scope = try #require(app.inspectionScope)
        let pending = Task { try await app.inspectProject(.activity, scope: scope) }
        await gate.untilEntered()
        await app.selectProject("A-two")
        await gate.open()
        await #expect(throws: CancellationError.self) { try await pending.value }
        await #expect(throws: CancellationError.self) { try await app.inspectProject(.domains, scope: scope) }
        let current = try #require(app.inspectionScope)
        await #expect(throws: VercelAPIError.self) { try await app.runtimeLogStream(scope: current, deploymentID: "A-one-deploy") }
        await app.disconnect()
        #expect(app.inspectionScope == nil)
        await #expect(throws: CancellationError.self) { try await app.inspectProject(.activity, scope: current) }
    }

    @Test @MainActor func runtimeBriefUsesCountsWithoutRawLogsAndClearsWhenTheSiteChanges() async throws {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0) }
        _ = await app.connectWithToken("A")
        await app.selectProject("A-one")
        let scope = try #require(app.inspectionScope)
        app.recordRuntimeSample(scope: scope, deploymentID: "A-one-deploy", records: 4, errors: 2)
        await app.runOpsBrief()
        #expect(app.opsNarrative?.body.contains("2 error-like") == true)
        #expect(app.opsNarrative?.body.contains("not a site-wide or hourly") == true)
        await app.selectProject("A-two")
        app.recordRuntimeSample(scope: scope, deploymentID: "A-one-deploy", records: 4, errors: 2)
        await app.runOpsBrief()
        #expect(app.opsNarrative?.body.contains("error-like") == false)
    }
    @MainActor private func session(root: URL, keychain: KeychainStore, factory: @escaping (String) -> any VercelAPIClient) -> AppSession {
        AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false, keychain: keychain,
                   modelAvailability: { false }, clientFactory: factory)
    }
    private var newRoot: URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private var newKeychain: KeychainStore { KeychainStore(service: "taktung.tests.\(UUID().uuidString)") }

    @Test @MainActor func failedReplacementKeepsClientAndEvidenceOnTheOriginalAccount() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { token in SessionTestAPI(account: token, projectsFail: token == "B") }
        _ = await app.connectWithToken("A")
        let original = app.evidenceScope
        _ = await app.connectWithToken("B")
        #expect(app.connection.user?.id == "A")
        #expect(app.connection.isConnected)
        #expect(app.evidenceScope == original)
        #expect(keys.load(KeychainStore.Key.accessToken) == "A")
        await app.refreshProjects()
        #expect(app.projects.allSatisfy { $0.id.hasPrefix("A-") })
    }

    @Test @MainActor func successfulReplacementClearsTheOldSelectionsBeforeWritingNewNotes() async throws {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0) }
        _ = await app.connectWithToken("A")
        await app.selectProject("A-one")
        await app.selectDeployment("A-one-deploy")
        app.requestMutation(mode: .redeploy)
        #expect(app.pendingMutation != nil)
        _ = await app.connectWithToken("B")
        #expect(app.selectedProjectId == nil)
        #expect(app.deployments.isEmpty)
        #expect(app.selectedDeployment == nil)
        #expect(app.pendingMutation == nil)
        let scope = try #require(app.evidenceScope)
        #expect(scope.accountID == "B")
        #expect(await app.addHistoryNote("B note", scope: scope, projectID: nil, deploymentID: nil))
        let note = try #require(try await app.evidenceStore.loadHistory(scope: scope)?.first { $0.detail == "B note" })
        #expect(note.projectId == nil && note.deploymentId == nil)
    }

    @Test @MainActor func selectedTeamHistoryRestoresOfflineAndPersonalChoiceSurvivesReconnect() async throws {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let teams = [VercelTeam(id: "team-one", name: "One", slug: "one")]
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0, teams: teams) }
        _ = await app.connectWithToken("A")
        #expect(keys.selectedTeamID() == "team-one")
        let teamScope = try #require(app.evidenceScope)
        #expect(await app.addHistoryNote("Team review", scope: teamScope, projectID: nil, deploymentID: nil))
        let offline = session(root: root, keychain: keys) { SessionTestAPI(account: $0, userFail: true) }
        await offline.bootstrap()
        #expect(offline.evidenceScope == teamScope)
        #expect(offline.recentActivity.contains { $0.detail == "Team review" })
        #expect(offline.hasLocalAccountData)
        await app.selectTeam(nil)
        _ = await app.connectWithToken("A")
        #expect(app.connection.selectedTeamId == nil)
        #expect(app.evidenceScope?.teamID == nil)
    }

    @Test @MainActor func staleDetailTaskCannotRetargetAMutationAfterChangingSite() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let gate = DeploymentGate()
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0, gate: gate) }
        _ = await app.connectWithToken("A")
        await app.selectProject("A-one")
        let preparation = Task {
            await app.selectDeployment("A-one-deploy")
            app.requestMutation(mode: .redeploy, expectedDeploymentID: "A-one-deploy")
        }
        await gate.untilEntered()
        await app.selectProject("A-two")
        await gate.open()
        await preparation.value
        #expect(app.pendingMutation == nil)
        #expect(app.selectedProjectId == "A-two")
    }

    @Test @MainActor func refreshedDetailReplacesTheBuildingListSummary() {
        let app = AppSession(demoMode: false)
        var summary = SessionTestAPI(account: "A").deployment("A-one")
        summary.state = .building
        var refreshed = summary
        refreshed.state = .ready
        app.deployments = [summary]
        app.selectedDeployment = refreshed
        #expect(app.deploymentForDisplay(summary).state == .ready)
    }

    @Test @MainActor func failedLogsThrowRatherThanReportAnEmptySuccessfulResult() async throws {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0, logsFail: $0 == "failure") }
        _ = await app.connectWithToken("failure")
        await #expect(throws: VercelAPIError.self) { try await app.loadBuildLogs(for: "failure-one-deploy") }
        _ = await app.connectWithToken("empty")
        #expect(try await app.loadBuildLogs(for: "empty-one-deploy").isEmpty)
    }

    @Test @MainActor func unavailableAuthenticationStillAllowsErasingLocalEvidence() async throws {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0) }
        _ = await app.connectWithToken("A")
        let scope = try #require(app.evidenceScope)
        #expect(await app.addHistoryNote("Private review", scope: scope, projectID: nil, deploymentID: nil))
        let offline = session(root: root, keychain: keys) { SessionTestAPI(account: $0, userFail: true) }
        await offline.bootstrap()
        #expect(offline.connection.status == .error)
        #expect(offline.hasLocalAccountData)
        await offline.disconnect()
        #expect(!offline.hasLocalAccountData)
        #expect(keys.load(KeychainStore.Key.accessToken) == nil)
        #expect(try await offline.evidenceStore.loadHistory(scope: scope) == nil)
    }

    @Test @MainActor func navigationDuringAReplacementDoesNotRestoreAnOlderScope() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let gate = DeploymentGate()
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0, projectsGate: $0 == "B" ? gate : nil) }
        _ = await app.connectWithToken("A")
        let replacement = Task { await app.connectWithToken("B") }
        await gate.untilEntered()
        await app.selectProject("A-two")
        await gate.open()
        _ = await replacement.value
        #expect(app.connection.user?.id == "A")
        #expect(app.evidenceScope?.accountID == "A")
        #expect(app.selectedProjectId == "A-two")
        #expect(keys.load(KeychainStore.Key.accessToken) == "A")
    }

    @Test @MainActor func disconnectDuringRestoredDeploymentLoadingRejectsTheConnectionResult() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let gate = DeploymentGate()
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: "A", deploymentsGate: $0 == "replacement" ? gate : nil) }
        _ = await app.connectWithToken("first")
        await app.selectProject("A-one")
        let replacement = Task { await app.connectWithToken("replacement") }
        await gate.untilEntered()
        await app.disconnect()
        await gate.open()
        let result = await replacement.value
        if case .connected = result { Issue.record("A disconnected attempt reported a successful connection") }
        #expect(!app.hasLocalAccountData)
        #expect(app.connection.status == .disconnected)
        #expect(keys.load(KeychainStore.Key.accessToken) == nil)
    }

    @Test @MainActor func analyticsRejectsResultsAfterSiteChangeOrReconnection() async throws {
        for breakdown in [false, true] {
            let root = newRoot, keys = newKeychain
            defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
            let gate = DeploymentGate()
            let app = session(root: root, keychain: keys) { _ in SessionTestAPI(account: "A", inspectionGate: gate) }
            _ = await app.connectWithToken("initial")
            await app.selectProject("A-one")
            let scope = try #require(app.inspectionScope)
            let request = Task {
                if breakdown { _ = try await app.loadAnalyticsSegments(scope: scope, dimension: .pages, window: AnalyticsPeriod.week.window()) }
                else { _ = try await app.loadAnalytics(scope: scope, window: AnalyticsPeriod.week.window()) }
            }
            await gate.untilEntered()
            if breakdown { _ = await app.connectWithToken("replacement") }
            else { await app.selectProject("A-two") }
            await gate.open()
            do { try await request.value; Issue.record("Old analytics published after scope changed") }
            catch { #expect(error is CancellationError) }
        }
    }

    @Test @MainActor func searchResultsOpenLikeLoadedDeploymentsUntilTheSiteChanges() async throws {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0) }
        _ = await app.connectWithToken("A")
        await app.selectProject("A-one")
        #expect(!app.knownDeployments.contains { $0.id == "A-one-older" })
        let found = try await app.searchDeployments(DeploymentQuery(states: [.ready]))
        #expect(found.map(\.id) == ["A-one-deploy", "A-one-older"])
        #expect(app.knownDeployments.map(\.id) == ["A-one-deploy", "A-one-older"])
        await app.selectDeployment("A-one-older")
        #expect(app.selectedDeployment?.id == "A-one-older")
        app.requestMutation(mode: .redeploy)
        #expect(app.pendingMutation != nil, "A searched deployment belongs to the selected site")
        await app.selectProject("A-two")
        #expect(app.searchedDeployments.isEmpty)
        #expect(!app.knownDeployments.contains { $0.id == "A-one-older" })
    }

    @Test @MainActor func modelReadsOnlyRequestsTheRulesCannotPlace() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let calls = SearchPlannerCalls()
        let app = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { true },
                             searchPlanner: { query, _ in
                                 await calls.record(query)
                                 return SearchModelDraft(intent: .deployments, timeframe: .lastHours, amount: 12)
                             },
                             clientFactory: { SessionTestAPI(account: $0) })
        _ = await app.connectWithToken("A")
        await app.selectProject("A-one")
        let plain = await app.interpretSearch("successful deployments")
        #expect(plain.interpreter == .rules)
        #expect(await calls.queries.isEmpty)
        let read = await app.interpretSearch("successful deploys while I slept")
        #expect(read.interpreter == .appleIntelligence)
        #expect(read.plan == .deployments(DeploymentQuery(states: [.ready], window: .lastHours(12))))
        #expect(await calls.queries == ["successful deploys while I slept"])
        // With the Search page's switch off, the rules answer alone.
        let rulesOnly = await app.interpretSearch("successful deploys while I slept", allowModel: false)
        #expect(rulesOnly.interpreter == .rules)
        #expect(await calls.queries.count == 1)
    }

    @Test @MainActor func recentSearchesStayInMemoryAndSkipSecrets() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = session(root: root, keychain: keys) { SessionTestAPI(account: $0) }
        _ = await app.connectWithToken("A")
        for query in ["failed deploys", "ready", "Failed deploys", "token vcp_secret", "a", "b", "c"] { app.rememberSearch(query) }
        #expect(app.recentSearches == ["c", "b", "a", "Failed deploys", "ready"])
        await app.disconnect()
        #expect(app.recentSearches.isEmpty)
    }
}
