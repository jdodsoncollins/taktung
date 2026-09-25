import Foundation
import Testing
@testable import Taktung

struct ProjectHealthTests {
    @Test func mapsUnknownState() {
        #expect(DeploymentState.map("READY") == .ready)
        #expect(DeploymentState.map("bogus") == .unknown)
        #expect(DeploymentState.map(nil) == .unknown)
    }

    @Test func failedProductionNeedsAttention() {
        let failed = sampleDeploy(id: "dpl_fail", state: .error, target: .production)
        let result = computeAttention(
            production: failed,
            latest: failed,
            lastSuccess: nil,
            latestFailed: failed
        )
        #expect(result.needsAttention)
        #expect(result.reason == .latestProductionFailed)
    }

    @Test func readyProductionIsClear() {
        let ready = sampleDeploy(id: "dpl_ok", state: .ready, target: .production)
        let result = computeAttention(
            production: ready,
            latest: ready,
            lastSuccess: ready,
            latestFailed: nil
        )
        #expect(!result.needsAttention)
        #expect(result.reason == .none)
    }

    @Test func summarizePicksProductionAndFailure() {
        let prod = sampleDeploy(id: "dpl_prod", state: .ready, target: .production, createdAt: 2)
        let fail = sampleDeploy(id: "dpl_fail", state: .error, target: .preview, createdAt: 1)
        let summary = summarizeDeployments([fail, prod])
        #expect(summary.production?.id == "dpl_prod")
        #expect(summary.latestFailed?.id == "dpl_fail")
        #expect(summary.lastSuccess?.id == "dpl_prod")
    }
}

private func sampleDeploy(
    id: String,
    state: DeploymentState,
    target: DeploymentTarget?,
    createdAt: TimeInterval = 1
) -> VercelDeploymentSummary {
    VercelDeploymentSummary(
        id: id,
        url: nil,
        name: "example",
        state: state,
        target: target,
        createdAt: createdAt,
        readyAt: nil,
        buildingAt: nil,
        source: "git",
        creatorUsername: "example",
        isRollbackCandidate: nil,
        region: "iad1",
        meta: GitMeta(),
        inspectorUrl: nil,
        aliases: nil,
        buildDurationMs: nil,
        lambdaOutputs: nil
    )
}
