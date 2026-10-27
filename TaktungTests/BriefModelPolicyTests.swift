import Foundation
import Testing
@testable import Taktung

struct BriefModelPolicyTests {
    @Test func boundsMultilingualSnapshotsBeforeTokenization() {
        let prompt = BriefModelPolicy.prompt(String(repeating: "変更。", count: 5_000))!
        #expect(prompt.utf8.count <= BriefModelPolicy.maximumInputBytes + "Site snapshot:\n".utf8.count)
        #expect(!prompt.contains("�"))
    }

    @Test func rejectsCredentialsEvenOutsideTheTruncatedPortion() {
        #expect(BriefModelPolicy.prompt(String(repeating: "safe ", count: 1_000) + "vcp_syntheticSecretForTesting123") == nil)
        #expect(BriefModelPolicy.prompt("API_KEY=synthetic-secret") == nil)
        #expect(BriefModelPolicy.prompt(" ") == nil)
        #expect(redactBuildLog("vcp_syntheticSecretForTesting123") == "[REDACTED]")
    }

    @Test func acceptsOnlyShortCompleteNonsecretResponses() {
        #expect(BriefModelPolicy.accept(" Production is ready. ") == "Production is ready.")
        #expect(BriefModelPolicy.accept("Production is") == nil)
        #expect(BriefModelPolicy.accept(String(repeating: "long ", count: 100) + ".") == nil)
        #expect(BriefModelPolicy.accept("Use vcp_syntheticSecretForTesting123.") == nil)
    }

    @Test func promptDoesNotDuplicateStepsOrConversationHistory() {
        let narrative = synthesizeOpsNarrative(.build(projectName: "Example", productionState: "READY"))
        let prompt = BriefModelPolicy.prompt(narrative.body)!
        #expect(prompt.contains("Production state: READY"))
        #expect(!prompt.contains("Next steps:"))
    }
}
