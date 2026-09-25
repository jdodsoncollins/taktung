import Testing
@testable import Taktung

struct ConfirmationPolicyTests {
    let policy = ConfirmationPolicy.shared

    @Test func readActionsAreReadOnly() {
        let d = policy.descriptor(for: .listProjects(teamId: nil))
        #expect(d.risk == .readOnly)
        #expect(d.confirmation == .none)
    }

    @Test func redeployRequiresHardConfirm() {
        let d = policy.descriptor(for: .redeploy(
            deploymentId: "dpl_1",
            projectId: "prj_1",
            teamId: "team_1",
            target: .production
        ))
        #expect(d.risk == .high)
        #expect(d.confirmation == .hardConfirm)
    }

    @Test func rollbackRequiresDestructiveConfirm() {
        let d = policy.descriptor(for: .rollbackProduction(
            deploymentId: "dpl_1",
            projectId: "prj_1",
            teamId: nil
        ))
        #expect(d.risk == .destructive)
        #expect(d.confirmation == .destructiveConfirm)
    }

    @Test func envDriftIsReadOnly() {
        let d = policy.descriptor(for: .checkEnvDrift(projectId: "prj_1", teamId: nil))
        #expect(d.confirmation == .none)
    }

    @Test func domainFirewallFlagsAreReadOnly() {
        for action in [
            TaktAction.diagnoseDomains(projectId: "prj_1", teamId: nil),
            .loadObservability(projectId: "prj_1", teamId: nil),
            .explainFirewall(projectId: "prj_1", teamId: nil),
            .listFeatureFlags(projectId: "prj_1", teamId: nil),
        ] {
            #expect(policy.descriptor(for: action).confirmation == .none)
        }
    }
}
