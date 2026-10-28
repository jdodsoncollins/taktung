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

    @Test func demoAndUnavailableModelsKeepTheRules() async {
        let root = newRoot, keys = newKeychain
        defer { keys.eraseAll(); try? FileManager.default.removeItem(at: root) }
        let calls = PlannerCalls()
        let demo = AppSession(evidenceStore: LocalEvidenceStore(root: root), demoMode: true, keychain: keys,
                              modelAvailability: { true },
                              fieldLogPlanner: { query, _ in await calls.record(query); return FieldLogModelDraft(categories: [.notes]) })
        let fromDemo = await demo.interpretFieldLogSearch("anything odd lately")
        #expect(fromDemo.interpreter == .rules)

        let unavailable = AppSession(evidenceStore: LocalEvidenceStore(root: newRoot), demoMode: false, keychain: newKeychain,
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
