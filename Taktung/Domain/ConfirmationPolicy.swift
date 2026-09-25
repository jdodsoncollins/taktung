import Foundation

/// Safety policy: redeploy / promote / rollback always hard-confirm.
/// Domain / firewall / flag mutations are not exposed as actions
/// (read-only diagnostics only). Env values never appear in payloads.
struct ConfirmationPolicy: Sendable {
    static let shared = ConfirmationPolicy()

    func risk(for action: TaktAction) -> ActionRisk {
        switch action {
        case .redeploy, .promoteToProduction:
            return .high
        case .rollbackProduction:
            return .destructive
        default:
            return .readOnly
        }
    }

    func requirement(for action: TaktAction) -> ConfirmationRequirement {
        switch risk(for: action) {
        case .readOnly: .none
        case .low: .inline
        case .medium: .review
        case .high: .hardConfirm
        case .destructive: .destructiveConfirm
        }
    }

    func descriptor(for action: TaktAction) -> ActionDescriptor {
        ActionDescriptor(
            id: newID(),
            action: action,
            title: title(for: action),
            summary: summary(for: action),
            risk: risk(for: action),
            confirmation: requirement(for: action),
            projectId: action.projectId,
            deploymentId: action.deploymentId
        )
    }

    private func title(for action: TaktAction) -> String {
        switch action {
        case .listProjects: "List Projects"
        case .listDeployments: "List Deployments"
        case .getDeployment: "Get Deployment"
        case .getBuildLogs: "Fetch Build Logs"
        case .compareDeployments: "Compare Deployments"
        case .checkEnvDrift: "Check Environment Drift"
        case .summarizeIncident: "Summarize Incident"
        case .diagnoseDomains: "Diagnose Domains"
        case .loadObservability: "Load Observability"
        case .explainFirewall: "Explain Firewall"
        case .listFeatureFlags: "List Feature Flags"
        case .queryRuntimeLogs: "Query Runtime Logs"
        case .waitForDeploymentReady: "Wait for Deployment READY"
        case .redeploy: "Redeploy"
        case .promoteToProduction: "Promote to Production"
        case .rollbackProduction: "Rollback Production"
        }
    }

    private func summary(for action: TaktAction) -> String {
        switch action {
        case .listProjects:
            "Refresh project list from Vercel"
        case .listDeployments(let projectId, _):
            "List deployments for project \(projectId)"
        case .getDeployment(let id, _):
            "Load deployment \(id)"
        case .getBuildLogs(let id, _):
            "Load build logs for \(id)"
        case .compareDeployments(_, let current, let baseline, _):
            "Compare \(current) with \(baseline)"
        case .checkEnvDrift(let projectId, _):
            "Compare env var presence for \(projectId) (names only)"
        case .summarizeIncident(_, let id, _):
            "Local incident summary for deployment \(id)"
        case .diagnoseDomains(let projectId, _):
            "Domain verification / DNS / SSL signals for \(projectId)"
        case .loadObservability(let projectId, _):
            "Observability snapshot for \(projectId) (honest empty states)"
        case .explainFirewall(let projectId, _):
            "Firewall explanation for \(projectId) (read-only)"
        case .listFeatureFlags(let projectId, _):
            "List feature flag metadata for \(projectId)"
        case .queryRuntimeLogs(_, _, _, let label):
            label
        case .waitForDeploymentReady(let id, _):
            "Poll \(id) until Vercel reports terminal state (READY only means success)"
        case .redeploy(let id, let projectId, _, let target):
            "Redeploy source \(id) for project \(projectId) to \(target?.rawValue ?? "its current target")"
        case .promoteToProduction(let id, let projectId, _):
            "Promote source \(id) for project \(projectId) to production"
        case .rollbackProduction(let id, let projectId, _):
            "Rollback project \(projectId) production to source \(id)"
        }
    }
}
