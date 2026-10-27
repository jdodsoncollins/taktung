import Foundation
import Testing
@testable import Taktung

private actor BriefProbe {
    private var continuations: [Int: CheckedContinuation<String?, Never>] = [:]
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var calls = 0

    func generate(_ input: String) async -> String? {
        await withCheckedContinuation { reply in
            calls += 1
            continuations[calls] = reply
            let ready = waiters.filter { $0.0 <= calls }
            waiters.removeAll { $0.0 <= calls }
            ready.forEach { $0.1.resume() }
        }
    }
    func untilCalls(_ count: Int) async {
        if calls >= count { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }
    func reply(_ number: Int, _ text: String?) { continuations.removeValue(forKey: number)?.resume(returning: text) }
}

private actor BriefCounter {
    private(set) var calls = 0
    func generate(_ input: String) -> String? { calls += 1; return "Production is ready in the loaded snapshot." }
}

struct BriefLifecycleTests {
    @Test @MainActor func generatedRuntimeSummaryCannotDropTheSampleQualifier() async throws {
        let keys = KeychainStore(service: "brief-sample-\(UUID())")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brief-sample-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let app = await app(keys: keys, root: root) { _ in "The site has two errors." }
        let scope = try #require(app.inspectionScope)
        app.recordRuntimeSample(scope: scope, deploymentID: app.deployments.first!.id, records: 4, errors: 2)
        await app.runOpsBrief()
        #expect(app.opsNarrative?.source == .heuristic)
        #expect(app.opsNarrative?.body.contains("bounded sample") == true)
        #expect(BriefModelPolicy.accept("The deployment sample contains two error-like records.", requiresSampleQualifier: true) != nil)
        #expect(BriefModelPolicy.accept("The domains need attention.", requiresOwnershipQualifier: true) == nil)
    }
    private func key(_ prompt: String = "Site snapshot: READY", project: String = "one") -> BriefReuseCache.Key {
        .init(accountID: "account", teamID: "team", projectID: project, prompt: prompt)
    }

    @Test func reuseRequiresIdenticalEvidenceScopeAndExpiresAfterFiveMinutes() {
        var cache = BriefReuseCache()
        let now = Date(timeIntervalSince1970: 1_000)
        cache.insert("Production is ready.", for: key(), now: now)
        #expect(cache.text(for: key(), now: now.addingTimeInterval(299)) != nil)
        #expect(cache.text(for: key(), now: now.addingTimeInterval(300)) == nil)
        #expect(cache.text(for: key(), now: now.addingTimeInterval(-1)) == nil)
        #expect(cache.text(for: key("Site snapshot: ERROR"), now: now) == nil)
        #expect(cache.text(for: key(project: "two"), now: now) == nil)
        var other = key(); other.accountID = "another"
        #expect(cache.text(for: other, now: now) == nil)
        cache.clear()
        #expect(cache.text(for: key(), now: now) == nil)
    }

    @Test func reuseIsBoundedAndRejectsSecretOrIncompleteOutput() {
        var cache = BriefReuseCache()
        for index in 0...BriefReuseCache.capacity { cache.insert("Production is ready.", for: key(project: "\(index)")) }
        #expect(cache.text(for: key(project: "0")) == nil)
        cache.insert("Use vcp_syntheticCredentialForTesting.", for: key())
        #expect(cache.text(for: key()) == nil)
        cache.insert("Production is", for: key())
        #expect(cache.text(for: key()) == nil)
        cache.insert("Production is ready.", for: key(String(repeating: "evidence ", count: 1_000)))
        #expect(cache.text(for: key(String(repeating: "evidence ", count: 1_000))) == nil)
        #expect(BriefModelPolicy.accept("Production is ready.\nRun a deployment.") == nil)
        #expect(BriefModelPolicy.accept(String(repeating: "word ", count: 46) + ".") == nil)
    }

    @MainActor private func app(keys: KeychainStore, root: URL,
                                generate: @escaping @Sendable (String) async -> String?) async -> AppSession {
        let app = AppSession(evidenceStore: .init(root: root), demoMode: false, keychain: keys,
                             modelAvailability: { true }, briefGenerator: generate,
                             clientFactory: { _ in DemoAPIClient() })
        _ = await app.connectWithToken("test-credential")
        await app.selectProject(DemoIDs.portfolio)
        return app
    }

    @MainActor @Test func repeatedChecksReuseAcceptedSummaryWithoutModelWork() async {
        let keys = KeychainStore(service: "brief-reuse-\(UUID())")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brief-reuse-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let counter = BriefCounter()
        let app = await app(keys: keys, root: root) { await counter.generate($0) }
        await app.runOpsBrief()
        await app.runOpsBrief()
        #expect(await counter.calls == 1)
        #expect(app.opsNarrative?.source == .appleFoundation && !app.isGeneratingBrief)
        await app.selectProject(DemoIDs.docs)
        await app.runOpsBrief()
        #expect(await counter.calls == 2)
    }

    @MainActor @Test func changingSiteCancelsObsoleteSummaryAndAllowsTheNewSiteImmediately() async {
        let keys = KeychainStore(service: "brief-scope-\(UUID())")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brief-scope-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let probe = BriefProbe()
        let app = await app(keys: keys, root: root) { await probe.generate($0) }
        let first = Task { await app.runOpsBrief() }
        await probe.untilCalls(1)
        #expect(app.opsNarrative?.source == .heuristic)
        #expect(!app.isBusy && app.isGeneratingBrief)
        await app.selectProject(DemoIDs.docs)
        #expect(!app.isGeneratingBrief)
        let second = Task { await app.runOpsBrief() }
        await probe.untilCalls(2)
        await probe.reply(2, "The new site's production is ready.")
        await second.value
        await probe.reply(1, "An obsolete response from the other site.")
        await first.value
        #expect(app.opsNarrative?.body == "The new site's production is ready.")
        #expect(!app.isGeneratingBrief && app.selectedProjectId == DemoIDs.docs)
    }

    @MainActor @Test func identicalConcurrentChecksDoNotStartAnotherGeneration() async {
        let keys = KeychainStore(service: "brief-concurrent-\(UUID())")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brief-concurrent-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let probe = BriefProbe()
        let app = await app(keys: keys, root: root) { await probe.generate($0) }
        let first = Task { await app.runOpsBrief() }
        await probe.untilCalls(1)
        await app.runOpsBrief()
        #expect(await probe.calls == 1)
        #expect(app.recentActivity.filter { $0.title == "Diagnose" }.count == 1)
        await probe.reply(1, "Production is ready.")
        await first.value
    }

    @MainActor @Test func disconnectCannotBeUndoneByALateModelReply() async {
        let keys = KeychainStore(service: "brief-disconnect-\(UUID())")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("brief-disconnect-\(UUID())")
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let probe = BriefProbe()
        let app = await app(keys: keys, root: root) { await probe.generate($0) }
        let work = Task { await app.runOpsBrief() }
        await probe.untilCalls(1)
        await app.disconnect()
        await probe.reply(1, "Production is ready.")
        await work.value
        #expect(app.opsNarrative == nil && !app.isGeneratingBrief)
        #expect(app.recentActivity.isEmpty && app.evidenceScope == nil)
    }
}
