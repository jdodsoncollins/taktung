import Foundation

struct MutationConfirmation: Sendable, Equatable {
    var projectId: ProjectID
    var sourceDeploymentId: DeploymentID
    var target: DeploymentTarget?
    var teamId: TeamID?
}

func mutationConfirmation(for action: TaktAction) -> MutationConfirmation? {
    switch action {
    case .redeploy(let deploymentId, let projectId, let teamId, let target):
        return MutationConfirmation(
            projectId: projectId,
            sourceDeploymentId: deploymentId,
            target: target,
            teamId: teamId
        )
    case .promoteToProduction(let deploymentId, let projectId, let teamId):
        return MutationConfirmation(
            projectId: projectId,
            sourceDeploymentId: deploymentId,
            target: .production,
            teamId: teamId
        )
    case .rollbackProduction(let deploymentId, let projectId, let teamId):
        return MutationConfirmation(
            projectId: projectId,
            sourceDeploymentId: deploymentId,
            target: .production,
            teamId: teamId
        )
    default:
        return nil
    }
}

func mutationConfirmationMatches(_ action: TaktAction, _ confirmation: MutationConfirmation?) -> Bool {
    guard let expected = mutationConfirmation(for: action) else { return true }
    return confirmation == expected
}

func sourceDeploymentBelongsToProject(
    _ sourceDeploymentId: DeploymentID,
    projectDeployments: [VercelDeploymentSummary]
) -> Bool {
    projectDeployments.contains { $0.id == sourceDeploymentId }
}

func formatMutationConfirmation(_ confirmation: MutationConfirmation) -> String {
    [
        "Project: \(confirmation.projectId)",
        "Source deployment: \(confirmation.sourceDeploymentId)",
        "Target: \(confirmation.target?.rawValue ?? "preserve source target")",
    ].joined(separator: "\n")
}
