import Foundation

/// In-memory Vercel client for demo mode. Never fetches.
struct DemoAPIClient: VercelAPIClient {
    func getUser() async throws -> VercelUser { demoUser }

    func listTeams() async throws -> [VercelTeam] { [demoTeam] }

    func listProjects(teamId: TeamID?) async throws -> [VercelProject] {
        buildDemoProjects()
    }

    func listDeployments(projectId: ProjectID, teamId: TeamID?, limit: Int) async throws -> [VercelDeploymentSummary] {
        Array(buildDemoDeployments(projectId: projectId).prefix(max(1, limit)))
    }

    func getDeployment(id: DeploymentID, teamId: TeamID?) async throws -> VercelDeploymentSummary {
        guard let found = findDemoDeployment(id) else {
            throw VercelAPIError.decodeFailed("deployment", "demo deployment missing")
        }
        return found
    }

    func getBuildLogLines(id: DeploymentID, teamId: TeamID?, limit: Int) async throws -> [BuildLogLine] {
        [
            BuildLogLine(text: "Compiling…", type: "stdout", created: Date().timeIntervalSince1970 * 1000 - 40_000),
            BuildLogLine(text: "Build completed.", type: "stdout", created: Date().timeIntervalSince1970 * 1000 - 8_000),
        ]
    }

    func listEnvVarMeta(projectId: ProjectID, teamId: TeamID?) async throws -> [EnvVarMeta] {
        [
            EnvVarMeta(
                id: "env_demo_1",
                key: "NEXT_PUBLIC_SITE_URL",
                type: "plain",
                target: ["production", "preview"]
            )
        ]
    }

    func redeploy(
        deploymentId: DeploymentID,
        projectId: ProjectID,
        teamId: TeamID?,
        target: DeploymentTarget?
    ) async throws -> VercelDeploymentSummary {
        throw VercelAPIError(status: 403, detail: "Demo mode cannot mutate deployments.")
    }
}
