import Testing
@testable import Taktung

struct OpsNarrativeTests {
    @Test func stableWhenNoIssues() {
        let n = synthesizeOpsNarrative(
            .build(projectName: "example-portfolio.app", productionState: "READY")
        )
        #expect(n.headline.contains("stable"))
        #expect(n.source == .heuristic)
        #expect(!containsSecretLike(n.body))
    }

    @Test func pollingDoesNotClaimReady() {
        let n = synthesizeOpsNarrative(
            .build(projectName: "site", polling: true)
        )
        #expect(n.headline.contains("Waiting"))
        #expect(n.body.contains("READY"))
        #expect(n.confidence == .high)
    }
}
