import Foundation

/// In-memory Vercel client for demo mode. Never fetches.
struct DemoAPIClient: VercelAPIClient {
    func analyticsOverview(projectID: ProjectID, teamID: TeamID?, window: AnalyticsWindow) async throws -> AnalyticsOverview {
        guard buildDemoProjects().contains(where: { $0.id == projectID }) else { throw VercelAPIError(status: 404, detail: "Demo project missing.") }
        let count = Int(window.until.timeIntervalSince(window.since) / 86_400)
        let days = (0..<count).map { index in
            AnalyticsDay(date: window.since.addingTimeInterval(Double(index) * 86_400),
                         counts: AnalyticsCounts(visitors: [18, 24, 20, 35, 29, 42, 37][index % 7], pageviews: [38, 51, 43, 72, 65, 94, 81][index % 7]))
        }
        return AnalyticsOverview(window: window, counts: .init(visitors: count == 7 ? 164 : 658, pageviews: days.reduce(0) { $0 + $1.counts.pageviews }), days: days)
    }

    func analyticsSegments(projectID: ProjectID, teamID: TeamID?, dimension: AnalyticsDimension, window: AnalyticsWindow) async throws -> [AnalyticsSegment] {
        let total = try await analyticsOverview(projectID: projectID, teamID: teamID, window: window)
        let labels: [String]
        switch dimension {
        case .pages: labels = ["/", "/projects", "/about", "Others"]
        case .referrers: labels = ["", "github.com", "google.com", "Others"]
        case .countries: labels = ["US", "GB", "DE", "Others"]
        case .devices: labels = ["desktop", "mobile", "tablet", "Others"]
        }
        let views = total.counts.pageviews
        let parts = [views / 2, views / 4, views / 8, views - views / 2 - views / 4 - views / 8]
        return zip(labels, parts).map { .init(key: $0.0, counts: .init(visitors: $0.1 / 2, pageviews: $0.1)) }
    }
    func inspect(_ tool: ProjectTool, projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID?) async throws -> InspectionResult {
        guard buildDemoProjects().contains(where: { $0.id == projectID }) else { throw VercelAPIError(status: 404, detail: "Demo project missing.") }
        let data: [String: Any]
        switch tool {
        case .activity:
            data = ["events": [["id": "demo-deploy", "type": "deployment-ready", "user": ["username": "alex"], "created": Date().timeIntervalSince1970 * 1000 - 60_000],
                               ["id": "demo-alias", "type": "alias", "user": ["username": "alex"], "created": Date().timeIntervalSince1970 * 1000 - 120_000]]]
        case .domains: data = ["domains": [["name": "\(projectID).example.com", "verified": true]]]
        case .checks: data = ["checks": [["id": "demo-check", "name": "Production smoke test", "status": "completed", "conclusion": "succeeded", "blocking": true]]]
        case .crons: data = ["id": projectID, "crons": ["definitions": [["path": "/api/cleanup", "schedule": "0 4 * * *"]]]]
        case .flags: data = ["data": [["id": "demo-flag", "slug": "new-checkout", "kind": "boolean"]]]
        }
        return try mapInspection(tool, raw: JSONValue(data))
    }

    func runtimeLogs(projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID) -> AsyncThrowingStream<RuntimeLogEntry, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.init(id: "demo-runtime-1", message: "GET / 200 · response served", level: "info", path: "/", statusCode: 200, timestamp: Date()))
            continuation.yield(.init(id: "demo-runtime-2", message: "Upstream request timed out", level: "error", path: "/api/catalog", statusCode: 504, timestamp: Date()))
            continuation.finish()
        }
    }
    func promote(deploymentId: DeploymentID, projectId: ProjectID, teamId: TeamID?) async throws {
        throw VercelAPIError(status: 403, detail: "Demo mode cannot mutate deployments.")
    }

    func rollback(deploymentId: DeploymentID, projectId: ProjectID, teamId: TeamID?) async throws {
        throw VercelAPIError(status: 403, detail: "Demo mode cannot mutate deployments.")
    }

    func productionDeploymentID(projectId: ProjectID, teamId: TeamID?) async throws -> DeploymentID? {
        buildDemoProjects().first { $0.id == projectId }?.productionDeployment?.id
    }
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
        if id.contains("fail") {
            return [
                BuildLogLine(text: "Running production build…", type: "stdout", created: nil),
                BuildLogLine(text: "Type error: Property 'title' does not exist on type 'PageProps'.", type: "stderr", created: nil),
                BuildLogLine(text: "Build failed. Fix the compile error before redeploying.", type: "stderr", created: nil),
            ]
        }
        return [
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
            ),
            EnvVarMeta(id: "env_demo_2", key: "DATABASE_URL", type: "encrypted", target: ["production", "preview"]),
            EnvVarMeta(id: "env_demo_3", key: "MAIL_API_KEY", type: "encrypted", target: ["preview"]),
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
