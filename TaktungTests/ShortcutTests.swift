import AppIntents
import Foundation
import Testing
@testable import Taktung

@Suite(.serialized)
struct ShortcutTests {
    private func context(source: WidgetDeploymentSnapshot.Source = .live) -> WidgetAccountContext {
        .init(revision: "revision", accountID: "account", teamID: "team", source: source,
              projects: [.init(id: "one", name: "Alpha site"), .init(id: "two", name: "Beta site")], cachedSnapshots: [])
    }
    private var keys: KeychainStore { .init(service: "shortcut-test-\(UUID())") }

    @Test func statusRefreshesOnlyTheRequestedScopeAndReturnsSampleSemantics() async throws {
        let keys = keys
        defer { keys.eraseAll() }
        try keys.save("test-credential", key: KeychainStore.Key.accessToken)
        keys.widgetStore.save(context())
        let service = ShortcutDeploymentStatus(store: keys.widgetStore, refresh: { seed, token in
            #expect(token == "test-credential" && seed.projectID == "one" && seed.teamID == "team")
            return .make(projectID: seed.projectID, projectName: seed.projectName, accountID: seed.accountID,
                         teamID: seed.teamID, revision: seed.revision, source: .live,
                         deployments: [.init(id: "d", name: "Alpha site", state: .building, target: .preview,
                                             createdAt: 1_000, meta: GitMeta())])
        })
        let text = try await service.read(projectID: "one")
        #expect(text.contains("Latest preview deployment: building"))
        #expect(text.contains("most recent 1") && text.contains("1 building or queued"))
        #expect(!text.contains("production"))
        #expect(keys.widgetStore.cachedSnapshot(for: context(), projectID: "one")?.building == 1)
    }

    @Test func emptyProjectMeansAllWithNoPerProjectFanOut() async throws {
        let keys = keys
        defer { keys.eraseAll() }
        try keys.save("test-credential", key: KeychainStore.Key.accessToken)
        keys.widgetStore.save(context())
        let service = ShortcutDeploymentStatus(store: keys.widgetStore, refresh: { seed, _ in
            #expect(seed.projectID == WidgetAccountContext.allProjectsID)
            return seed
        })
        #expect(try await service.read(projectID: nil) == "No deployments were found for All projects.")
    }

    @Test func demoAndMissingCredentialsCannotProduceLiveShortcutStatus() async throws {
        let keys = keys
        defer { keys.eraseAll() }
        keys.widgetStore.save(context(source: .demo))
        let service = ShortcutDeploymentStatus(store: keys.widgetStore, refresh: { seed, _ in
            Issue.record("A demo or disconnected shortcut must not fetch.")
            return seed
        })
        await #expect(throws: ShortcutFailure.self) { try await service.read(projectID: nil) }
        try keys.save("test-credential", key: KeychainStore.Key.accessToken)
        await #expect(throws: ShortcutFailure.self) { try await service.read(projectID: nil) }
    }

    @Test func deletedProjectCannotBecomeAllProjects() async throws {
        let keys = keys
        defer { keys.eraseAll() }
        try keys.save("test-credential", key: KeychainStore.Key.accessToken)
        keys.widgetStore.save(context())
        let service = ShortcutDeploymentStatus(store: keys.widgetStore, refresh: { seed, _ in
            Issue.record("A removed project must not fetch.")
            return seed
        })
        await #expect(throws: ShortcutFailure.self) { try await service.read(projectID: "removed") }
    }

    @Test func workspaceOrTokenChangeDuringFetchDiscardsTheReplyAndCache() async throws {
        for changeToken in [false, true] {
            let keys = keys
            defer { keys.eraseAll() }
            try keys.save("test-credential", key: KeychainStore.Key.accessToken)
            let original = context()
            keys.widgetStore.save(original)
            let store = keys.widgetStore
            let service = ShortcutDeploymentStatus(store: store, refresh: { seed, _ in
                if changeToken { try keys.save("replacement", key: KeychainStore.Key.accessToken) }
                else {
                    var other = original; other.revision = "new"; other.teamID = nil
                    store.save(other)
                }
                return seed
            })
            await #expect(throws: ShortcutFailure.self) { try await service.read(projectID: "one") }
            #expect(store.cachedSnapshot(for: original, projectID: "one") == nil)
        }
    }

    @Test func authFailureDoesNotReadBackAnOlderSuccessfulCache() async throws {
        let keys = keys
        defer { keys.eraseAll() }
        try keys.save("test-credential", key: KeychainStore.Key.accessToken)
        let context = context()
        keys.widgetStore.save(context)
        keys.widgetStore.saveCache(context.seed(for: "one")!)
        let service = ShortcutDeploymentStatus(store: keys.widgetStore, refresh: { _, _ in
            throw WidgetDeploymentService.Failure.unauthorized
        })
        await #expect(throws: ShortcutFailure.self) { try await service.read(projectID: "one") }
    }

    @Test func projectQueryUsesCurrentCatalogAndSupportsNameDisambiguation() async throws {
        let keys = keys
        defer { keys.eraseAll() }
        try keys.save("test-credential", key: KeychainStore.Key.accessToken)
        keys.widgetStore.save(context())
        let query = ProjectQuery(store: keys.widgetStore)
        #expect(try await query.entities(matching: " alpha ").map(\.id) == ["one"])
        #expect(try await query.entities(for: ["removed", "two"]).map(\.id) == ["two"])
        #expect(try await query.suggestedEntities().map(\.id) == ["one", "two"])
        keys.widgetStore.clear()
        #expect(try await query.suggestedEntities().isEmpty)
    }

    @Test @MainActor func routerKeepsColdLaunchRequestsAndConsumesEachOnce() async throws {
        let router = TaktRouter()
        let first = ShortcutRoute(section: .home, action: .checkHealth, projectID: "one")
        router.enqueue(first)
        #expect(router.pending == first)
        #expect(router.takePending() == first)
        #expect(router.takePending() == nil)
        // Exercise an actual legacy intent's handoff, not a notification stub.
        _ = TaktRouter.shared.takePending()
        _ = try await OpenDeploymentsIntent().perform()
        #expect(TaktRouter.shared.takePending()?.section == .deploys)
    }

    @Test func routesRespectWorkspaceAndAllowOnlyKnownLocalDestinations() {
        let route = ShortcutRoute(section: .home, projectID: "one", accountID: "account", teamID: "team")
        #expect(route.matches(accountID: "account", teamID: "team"))
        #expect(!route.matches(accountID: "other", teamID: "team"))
        #expect(!route.matches(accountID: "account", teamID: nil))
        #expect(ShortcutRoute.from(URL(string: "takt://deploys")!)?.section == .deploys)
        #expect(ShortcutRoute.from(URL(string: "https://deploys")!) == nil)
        #expect(ShortcutRoute.from(URL(string: "takt://redeploy")!) == nil)
        #expect(GetDeploymentStatusIntent.authenticationPolicy == .requiresAuthentication)
        #expect(CheckSiteHealthIntent.openAppWhenRun)
        #expect(!GetDeploymentStatusIntent.openAppWhenRun)
    }

    @Test @MainActor func healthHandoffSelectsProjectAndUsesHeuristicWithoutTheModel() async throws {
        let keys = keys
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shortcut-route-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = AppSession(evidenceStore: .init(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { false }, clientFactory: { _ in DemoAPIClient() })
        _ = await app.connectWithToken("test-credential")
        let project = try #require(app.projects.last)
        let route = ShortcutRoute(section: .home, action: .checkHealth, projectID: project.id,
                                  accountID: app.connection.user?.id, teamID: app.connection.selectedTeamId)
        await app.handleShortcutRoute(route)
        #expect(app.selectedProjectId == project.id && app.opsNarrative?.source == .heuristic)
        #expect(app.pendingMutation == nil)
        var wrong = route; wrong.accountID = "another account"
        await app.handleShortcutRoute(wrong)
        #expect(app.lastError == ShortcutFailure.workspaceChanged.localizedDescription)
        #expect(app.selectedProjectId == project.id)
    }

    @Test @MainActor func systemHandoffRevealsItsDestinationAndCancelsAnUnconfirmedPlan() async throws {
        let keys = keys
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shortcut-overlays-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = AppSession(evidenceStore: .init(root: root), demoMode: true, keychain: keys)
        await app.bootstrap()
        app.settingsOpen = true
        app.sitePickerOpen = true
        app.requestMutation(mode: .redeploy)
        #expect(app.pendingMutation != nil)
        await app.handleShortcutRoute(.init(section: .deploys))
        #expect(!app.settingsOpen && !app.sitePickerOpen && app.pendingMutation == nil)
    }
}
