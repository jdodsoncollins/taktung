import Testing
@testable import Taktung

struct MutationSafetyTests {
    @Test func confirmationMustMatch() {
        let action = TaktAction.redeploy(
            deploymentId: "dpl_1",
            projectId: "prj_1",
            teamId: "team_1",
            target: .production
        )
        let matching = mutationConfirmation(for: action)
        #expect(mutationConfirmationMatches(action, matching))
        let wrong = MutationConfirmation(
            projectId: "prj_other",
            sourceDeploymentId: "dpl_1",
            target: .production,
            teamId: "team_1"
        )
        #expect(!mutationConfirmationMatches(action, wrong))
        #expect(!mutationConfirmationMatches(action, nil))
    }

    @Test func readsDoNotNeedConfirmationPayload() {
        #expect(mutationConfirmationMatches(.listProjects(teamId: nil), nil))
    }

    @Test func sourceMustBelongToProject() {
        let deploy = VercelDeploymentSummary(
            id: "dpl_1",
            url: nil,
            name: "n",
            state: .ready,
            target: .production,
            createdAt: 1,
            readyAt: nil,
            buildingAt: nil,
            source: nil,
            creatorUsername: nil,
            isRollbackCandidate: nil,
            region: nil,
            meta: GitMeta(),
            inspectorUrl: nil,
            aliases: nil,
            buildDurationMs: nil,
            lambdaOutputs: nil
        )
        #expect(sourceDeploymentBelongsToProject("dpl_1", projectDeployments: [deploy]))
        #expect(!sourceDeploymentBelongsToProject("dpl_2", projectDeployments: [deploy]))
    }
}
