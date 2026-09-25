import Foundation

enum ActionRisk: String, Sendable {
    case readOnly
    case low
    case medium
    case high
    case destructive
}

enum ConfirmationRequirement: String, Sendable {
    case none
    case inline
    case review
    case hardConfirm
    case destructiveConfirm
}

/// Allow-listed Taktung actions. Model output must map to these only.
enum TaktAction: Sendable, Hashable {
    case listProjects(teamId: TeamID?)
    case listDeployments(projectId: ProjectID, teamId: TeamID?)
    case getDeployment(deploymentId: DeploymentID, teamId: TeamID?)
    case getBuildLogs(deploymentId: DeploymentID, teamId: TeamID?)
    case compareDeployments(
        projectId: ProjectID,
        currentId: DeploymentID,
        baselineId: DeploymentID,
        teamId: TeamID?
    )
    case checkEnvDrift(projectId: ProjectID, teamId: TeamID?)
    case summarizeIncident(projectId: ProjectID, deploymentId: DeploymentID, teamId: TeamID?)
    case diagnoseDomains(projectId: ProjectID, teamId: TeamID?)
    case loadObservability(projectId: ProjectID, teamId: TeamID?)
    case explainFirewall(projectId: ProjectID, teamId: TeamID?)
    case listFeatureFlags(projectId: ProjectID, teamId: TeamID?)
    case queryRuntimeLogs(projectId: ProjectID, teamId: TeamID?, deploymentId: DeploymentID?, label: String)
    case waitForDeploymentReady(deploymentId: DeploymentID, teamId: TeamID?)
    case redeploy(
        deploymentId: DeploymentID,
        projectId: ProjectID,
        teamId: TeamID?,
        target: DeploymentTarget?
    )
    case promoteToProduction(deploymentId: DeploymentID, projectId: ProjectID, teamId: TeamID?)
    case rollbackProduction(deploymentId: DeploymentID, projectId: ProjectID, teamId: TeamID?)

    var projectId: ProjectID? {
        switch self {
        case .listProjects: nil
        case .listDeployments(let projectId, _): projectId
        case .getDeployment, .getBuildLogs, .waitForDeploymentReady: nil
        case .compareDeployments(let projectId, _, _, _): projectId
        case .checkEnvDrift(let projectId, _): projectId
        case .summarizeIncident(let projectId, _, _): projectId
        case .diagnoseDomains(let projectId, _): projectId
        case .loadObservability(let projectId, _): projectId
        case .explainFirewall(let projectId, _): projectId
        case .listFeatureFlags(let projectId, _): projectId
        case .queryRuntimeLogs(let projectId, _, _, _): projectId
        case .redeploy(_, let projectId, _, _): projectId
        case .promoteToProduction(_, let projectId, _): projectId
        case .rollbackProduction(_, let projectId, _): projectId
        }
    }

    var deploymentId: DeploymentID? {
        switch self {
        case .getDeployment(let id, _): id
        case .getBuildLogs(let id, _): id
        case .summarizeIncident(_, let id, _): id
        case .queryRuntimeLogs(_, _, let id, _): id
        case .waitForDeploymentReady(let id, _): id
        case .redeploy(let id, _, _, _): id
        case .promoteToProduction(let id, _, _): id
        case .rollbackProduction(let id, _, _): id
        default: nil
        }
    }
}

struct ActionDescriptor: Sendable, Identifiable {
    var id: String
    var action: TaktAction
    var title: String
    var summary: String
    var risk: ActionRisk
    var confirmation: ConfirmationRequirement
    var projectId: ProjectID?
    var deploymentId: DeploymentID?
}

struct ActionPlan: Sendable, Identifiable {
    var id: String
    var title: String
    var rationale: String
    var steps: [ActionDescriptor]
    var createdAt: Date
}
