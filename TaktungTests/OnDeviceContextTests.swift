import Foundation
import Testing
@testable import Taktung

private actor PlannerCalls {
    private(set) var queries: [String] = []
    func record(_ query: String) { queries.append(query) }
}

/// Session behavior for on-device context: what reaches the model, and when.
@MainActor
struct OnDeviceContextTests {
    private var newRoot: URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private var newKeychain: KeychainStore { KeychainStore(service: "taktung.tests.\(UUID().uuidString)") }

    @Test func fieldLogModelReadsOnlyRequestsTheRulesCannotPlace() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let calls = PlannerCalls()
        let app = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { true },
                             fieldLogPlanner: { query, sites in
                                 await calls.record(query + " | " + sites.joined(separator: ","))
                                 return FieldLogModelDraft(categories: [.notes], text: "checkout")
                             },
                             clientFactory: { _ in DemoAPIClient() })
        _ = await app.connectWithToken("token")
        let plain = await app.interpretFieldLogSearch("failed checks this week")
        #expect(plain.interpreter == .rules)
        #expect(await calls.queries.isEmpty)

        let read = await app.interpretFieldLogSearch("what did I jot down while fixing checkout")
        #expect(read.interpreter == .appleIntelligence)
        #expect(read.query.categories == [.notes])
        #expect(read.query.text == "checkout")
        let sent = await calls.queries
        #expect(sent.count == 1)
        // Only the request and site names; no journal text.
        #expect(sent.first?.hasPrefix("what did I jot down while fixing checkout | ") == true)
    }

    @Test func failedBuildShowsKeyLinesAndAGroundedExplanation() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let sent = PlannerCalls()
        let app = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { true },
                             buildExplainer: { excerpt in
                                 await sent.record(excerpt.text)
                                 return "A type error stopped the build: 'title' does not exist on type 'PageProps'."
                             },
                             clientFactory: { _ in DemoAPIClient() })
        _ = await app.connectWithToken("token")
        await app.selectProject(DemoIDs.portfolio)
        await app.runIncidentSummary()
        let evidence = app.buildFailure
        #expect(evidence?.deploymentID == app.incidentDeploymentId)
        #expect(evidence?.excerpt.lines.contains { $0.hasPrefix("Type error") } == true)
        for _ in 0..<500 where app.buildFailure?.isExplaining == true { await Task.yield() }
        #expect(app.buildFailure?.explanation == "A type error stopped the build: 'title' does not exist on type 'PageProps'.")
        #expect(await sent.queries == [evidence?.excerpt.text ?? ""])
        // The Field Log keeps the heuristic only; the generated sentence stays in memory.
        #expect(!app.recentActivity.contains { $0.detail.contains("stopped the build") })

        await app.selectProject(DemoIDs.store)
        #expect(app.buildFailure == nil)
    }

    @Test func ungroundedExplanationsAndDemoKeepOnlyTheKeyLines() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { true },
                             buildExplainer: { _ in "The file src/app/layout.tsx imports a missing package." },
                             clientFactory: { _ in DemoAPIClient() })
        _ = await app.connectWithToken("token")
        await app.selectProject(DemoIDs.portfolio)
        await app.runIncidentSummary()
        for _ in 0..<500 where app.buildFailure?.isExplaining == true { await Task.yield() }
        #expect(app.buildFailure?.explanation == nil)
        #expect(app.buildFailure?.excerpt.lines.isEmpty == false)

        let calls = PlannerCalls()
        let demoRoot = newRoot, demoKeys = newKeychain
        defer { demoKeys.eraseAll(); try? FileManager.default.removeItem(at: demoRoot) }
        let demo = AppSession(evidenceStore: LocalEvidenceStore(root: demoRoot), demoMode: true, keychain: demoKeys,
                              modelAvailability: { true },
                              buildExplainer: { excerpt in await calls.record(excerpt.text); return nil })
        await demo.bootstrap()
        await demo.runIncidentSummary()
        #expect(demo.buildFailure?.excerpt.lines.isEmpty == false)
        #expect(demo.buildFailure?.isExplaining == false)
        #expect(await calls.queries.isEmpty)
    }

    @Test func demoAndUnavailableModelsKeepTheRules() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let calls = PlannerCalls()
        let demo = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: true, keychain: keys,
                              modelAvailability: { true },
                              fieldLogPlanner: { query, _ in await calls.record(query); return FieldLogModelDraft(categories: [.notes]) })
        let fromDemo = await demo.interpretFieldLogSearch("anything odd lately")
        #expect(fromDemo.interpreter == .rules)

        let otherRoot = newRoot, otherKeys = newKeychain
        defer { otherKeys.eraseAll(); try? FileManager.default.removeItem(at: otherRoot) }
        let unavailable = AppSession(evidenceStore: LocalEvidenceStore(root: otherRoot), demoMode: false, keychain: otherKeys,
                                     modelAvailability: { false },
                                     fieldLogPlanner: { query, _ in await calls.record(query); return FieldLogModelDraft(categories: [.notes]) },
                                     clientFactory: { _ in DemoAPIClient() })
        _ = await unavailable.connectWithToken("token")
        let fromRules = await unavailable.interpretFieldLogSearch("anything odd lately")
        #expect(fromRules.interpreter == .rules)
        #expect(fromRules.query.text == "odd")
        #expect(await calls.queries.isEmpty)
    }
}
