import Foundation

protocol VercelAPIClient: Sendable {
    func getUser() async throws -> VercelUser
    func listTeams() async throws -> [VercelTeam]
    func listProjects(teamId: TeamID?) async throws -> [VercelProject]
    func listDeployments(projectId: ProjectID, teamId: TeamID?, limit: Int) async throws -> [VercelDeploymentSummary]
    func getDeployment(id: DeploymentID, teamId: TeamID?) async throws -> VercelDeploymentSummary
    func getBuildLogLines(id: DeploymentID, teamId: TeamID?, limit: Int) async throws -> [BuildLogLine]
    func listEnvVarMeta(projectId: ProjectID, teamId: TeamID?) async throws -> [EnvVarMeta]
    func redeploy(
        deploymentId: DeploymentID,
        projectId: ProjectID,
        teamId: TeamID?,
        target: DeploymentTarget?
    ) async throws -> VercelDeploymentSummary
}

final class LiveVercelAPIClient: VercelAPIClient, @unchecked Sendable {
    private let baseURL: URL
    private let tokenProvider: @Sendable () async throws -> String?
    private let session: URLSession
    private let maxPages = 100

    init(
        tokenProvider: @escaping @Sendable () async throws -> String?,
        baseURL: URL = AppConfig.vercelAPIBase,
        session: URLSession = .shared
    ) {
        self.tokenProvider = tokenProvider
        self.baseURL = baseURL
        self.session = session
    }

    func getUser() async throws -> VercelUser {
        let json = try await requestJSON(path: "/v2/user")
        guard let u = json["user"],
              let id = u["id"]?.string,
              let username = u["username"]?.string
        else {
            throw VercelAPIError.decodeFailed("user", "missing id/username")
        }
        return VercelUser(
            id: id,
            name: u["name"]?.string,
            username: username,
            email: u["email"]?.string
        )
    }

    func listTeams() async throws -> [VercelTeam] {
        var teams: [VercelTeam] = []
        var until: Int?
        for _ in 0..<maxPages {
            var query = ["limit": "100"]
            if let until { query["until"] = String(until) }
            let data = try await requestJSON(path: "/v2/teams", query: query)
            let page = data["teams"]?.array ?? []
            for t in page {
                if let id = t["id"]?.string, let name = t["name"]?.string, let slug = t["slug"]?.string {
                    teams.append(VercelTeam(id: id, name: name, slug: slug))
                }
            }
            let next = data["pagination"]?["next"]?.int
            if next == nil || next == until { break }
            until = next
        }
        return teams
    }

    func listProjects(teamId: TeamID?) async throws -> [VercelProject] {
        var raw: [JSONValue] = []
        var from: String?
        for _ in 0..<maxPages {
            var query = ["limit": "100"]
            if let teamId { query["teamId"] = teamId }
            if let from { query["from"] = from }
            let data = try await requestJSON(path: "/v10/projects", query: query)
            if let arr = data.array {
                raw.append(contentsOf: arr)
                break
            }
            raw.append(contentsOf: data["projects"]?.array ?? [])
            let next = data["pagination"]?["next"]?.string
                ?? data["pagination"]?["next"]?.int.map(String.init)
            if next == nil || next == from { break }
            from = next
        }

        // No per-project listDeployments (N+1). Prefer embedded
        // latestDeployments + targets.production from the projects list.
        var projects: [VercelProject] = []
        for p in raw {
            guard let id = p["id"]?.string, let name = p["name"]?.string else { continue }
            let embedded = (p["latestDeployments"]?.array ?? []).compactMap(mapRawDeployment)
            let summarized = summarizeDeployments(embedded)
            var prodFromTarget: VercelDeploymentSummary?
            if var target = p["targets"]?["production"] {
                // Force production target on the mapped row.
                if case .object(var obj) = target {
                    obj["target"] = .string("production")
                    target = .object(obj)
                }
                prodFromTarget = mapRawDeployment(target)
                if var mapped = prodFromTarget { mapped.target = .production; prodFromTarget = mapped }
            }
            let production = summarized.production ?? prodFromTarget
            let attention = computeAttention(
                production: production ?? summarized.production,
                latest: summarized.latest ?? production,
                lastSuccess: summarized.lastSuccess,
                latestFailed: summarized.latestFailed
            )
            let primaryDomain =
                production?.aliases?.first ?? production?.url ?? summarized.latest?.url
            let link: ProjectLink? = p["link"].map {
                ProjectLink(
                    type: $0["type"]?.string ?? "unknown",
                    repo: $0["repo"]?.string,
                    org: $0["org"]?.string
                )
            }
            projects.append(
                VercelProject(
                    id: id,
                    name: name,
                    framework: p["framework"]?.string,
                    nodeVersion: p["nodeVersion"]?.string,
                    primaryDomain: primaryDomain,
                    productionDeployment: production ?? summarized.production,
                    latestDeployment: summarized.latest ?? production,
                    lastSuccessfulDeployment: summarized.lastSuccess,
                    latestFailedDeployment: summarized.latestFailed,
                    needsAttention: attention.needsAttention,
                    attentionReason: attention.reason,
                    teamId: teamId,
                    link: link
                )
            )
        }
        projects.sort { a, b in
            if a.needsAttention != b.needsAttention { return a.needsAttention && !b.needsAttention }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return projects
    }

    func listDeployments(projectId: ProjectID, teamId: TeamID?, limit: Int = 20) async throws -> [VercelDeploymentSummary] {
        let requested = max(1, limit)
        var deployments: [JSONValue] = []
        var until: Int?
        for _ in 0..<maxPages where deployments.count < requested {
            var query: [String: String] = [
                "projectId": projectId,
                "limit": String(min(100, requested - deployments.count)),
            ]
            if let teamId { query["teamId"] = teamId }
            if let until { query["until"] = String(until) }
            let data = try await requestJSON(path: "/v7/deployments", query: query)
            deployments.append(contentsOf: data["deployments"]?.array ?? [])
            let next = data["pagination"]?["next"]?.int
            if next == nil || next == until { break }
            until = next
        }
        return deployments.compactMap(mapRawDeployment).prefix(requested).map { $0 }
    }

    func getDeployment(id: DeploymentID, teamId: TeamID?) async throws -> VercelDeploymentSummary {
        var query: [String: String] = [:]
        if let teamId { query["teamId"] = teamId }
        let data = try await requestJSON(path: "/v13/deployments/\(id)", query: query)
        guard var mapped = mapRawDeployment(data) else {
            throw VercelAPIError.decodeFailed("deployment", "missing id")
        }
        let buildingAt = data["buildingAt"]?.double ?? mapped.buildingAt
        let ready = data["ready"]?.double ?? mapped.readyAt
        if let buildingAt, let ready, ready >= buildingAt {
            mapped.buildDurationMs = ready - buildingAt
        }
        if let aliases = data["alias"]?.array {
            mapped.aliases = aliases.compactMap(\.string)
        }
        return mapped
    }

    func getBuildLogLines(id: DeploymentID, teamId: TeamID?, limit: Int = 100) async throws -> [BuildLogLine] {
        var query = ["builds": "1", "direction": "forward"]
        if let teamId { query["teamId"] = teamId }
        let data = try await requestJSON(path: "/v3/deployments/\(id)/events", query: query)
        let events = data.array ?? data["events"]?.array ?? []
        var lines: [BuildLogLine] = []
        for e in events {
            let text = e["payload"]?["text"]?.string ?? e["text"]?.string ?? ""
            if text.isEmpty { continue }
            lines.append(
                BuildLogLine(
                    text: text,
                    type: e["type"]?.string ?? e["payload"]?["info"]?["type"]?.string,
                    created: e["created"]?.double
                )
            )
        }
        if lines.count > limit { return Array(lines.suffix(limit)) }
        return lines
    }

    func listEnvVarMeta(projectId: ProjectID, teamId: TeamID?) async throws -> [EnvVarMeta] {
        var query = ["decrypt": "false"]
        if let teamId { query["teamId"] = teamId }
        let data = try await requestJSON(path: "/v10/projects/\(projectId)/env", query: query)
        let rows = data.array ?? data["envs"]?.array ?? []
        return rows.compactMap { raw in
            guard let id = raw["id"]?.string, let key = raw["key"]?.string else { return nil }
            let target: [String]
            if let arr = raw["target"]?.array {
                target = arr.compactMap(\.string)
            } else if let s = raw["target"]?.string {
                target = [s]
            } else {
                target = []
            }
            // Never surface `value` even if the API included it.
            return EnvVarMeta(
                id: id,
                key: key,
                type: raw["type"]?.string ?? "plain",
                target: target,
                gitBranch: raw["gitBranch"]?.string,
                createdAt: raw["createdAt"]?.double,
                updatedAt: raw["updatedAt"]?.double
            )
        }
    }

    func redeploy(
        deploymentId: DeploymentID,
        projectId: ProjectID,
        teamId: TeamID?,
        target: DeploymentTarget?
    ) async throws -> VercelDeploymentSummary {
        let source = try await getDeployment(id: deploymentId, teamId: teamId)
        var body: [String: Any] = [
            "name": source.name,
            "project": projectId,
            "deploymentId": source.id,
            "meta": [
                "action": "redeploy",
                "sourceDeploymentId": source.id,
            ],
        ]
        if let target { body["target"] = target.rawValue }
        var query: [String: String] = [:]
        if let teamId { query["teamId"] = teamId }
        let data = try await requestJSON(
            path: "/v13/deployments",
            query: query,
            method: "POST",
            jsonBody: body
        )
        guard let mapped = mapRawDeployment(data) else {
            throw VercelAPIError.decodeFailed("redeploy", "missing id in response")
        }
        return mapped
    }

    private func requestJSON(
        path: String,
        query: [String: String] = [:],
        method: String = "GET",
        jsonBody: [String: Any]? = nil
    ) async throws -> JSONValue {
        guard let token = try await tokenProvider(), !token.isEmpty else {
            throw VercelAPIError(status: 401, detail: "Missing Vercel access token.")
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent(String(path.dropFirst())),
            resolvingAgainstBaseURL: false
        )
        // appendingPathComponent mangles query-less paths that already include nested segments.
        // Build from string instead when path starts with /.
        var url = baseURL
        if path.hasPrefix("/") {
            url = URL(string: baseURL.absoluteString + path)!
        }
        components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let finalURL = components?.url else {
            throw VercelAPIError(status: nil, detail: "Invalid Vercel URL")
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let jsonBody {
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 204 { return .null }
        if !(200..<300).contains(status) {
            let parsed = (try? JSONSerialization.jsonObject(with: data)).map { JSONValue($0) }
            let message =
                parsed?["error"]?["message"]?.string
                ?? parsed?["message"]?.string
                ?? String(data: data, encoding: .utf8)
                ?? "HTTP \(status)"
            throw VercelAPIError(status: status, detail: message)
        }
        if data.isEmpty { return .null }
        let obj = try JSONSerialization.jsonObject(with: data)
        return JSONValue(obj)
    }
}

func mapRawDeployment(_ raw: JSONValue) -> VercelDeploymentSummary? {
    let id = raw["uid"]?.string ?? raw["id"]?.string
    guard let id else { return nil }
    let metaRaw = raw["meta"] ?? .object([:])
    let stateRaw = raw["readyState"]?.string ?? raw["state"]?.string
    let targetRaw = raw["target"]?.string
    let target: DeploymentTarget? =
        targetRaw.flatMap { DeploymentTarget(rawValue: $0) }
    let createdAt = raw["created"]?.double ?? raw["createdAt"]?.double ?? Date().timeIntervalSince1970 * 1000
    let buildingAt = raw["buildingAt"]?.double
    let readyAt = raw["ready"]?.double ?? raw["readyAt"]?.double
    var url = raw["url"]?.string
    if let u = url, !u.hasPrefix("http") {
        url = "https://\(u)"
    }
    let name = raw["name"]?.string ?? raw["project"]?.string ?? "deployment"
    let creator = raw["creator"]?["username"]?.string
    let region = raw["regions"]?.array?.compactMap(\.string).first
        ?? raw["region"]?.string
    let aliases = raw["alias"]?.array?.compactMap(\.string)
    return VercelDeploymentSummary(
        id: id,
        url: url,
        name: name,
        state: DeploymentState.map(stateRaw),
        target: target,
        createdAt: createdAt,
        readyAt: readyAt,
        buildingAt: buildingAt,
        source: raw["source"]?.string,
        creatorUsername: creator,
        isRollbackCandidate: raw["isRollbackCandidate"]?.bool,
        region: region,
        meta: GitMeta(
            githubCommitRef: metaRaw["githubCommitRef"]?.string,
            githubCommitSha: metaRaw["githubCommitSha"]?.string,
            githubCommitMessage: metaRaw["githubCommitMessage"]?.string,
            githubCommitAuthorName: metaRaw["githubCommitAuthorName"]?.string,
            githubCommitAuthorLogin: metaRaw["githubCommitAuthorLogin"]?.string
        ),
        inspectorUrl: raw["inspectorUrl"]?.string,
        aliases: aliases,
        buildDurationMs: {
            if let buildingAt, let readyAt, readyAt >= buildingAt { return readyAt - buildingAt }
            return nil
        }(),
        lambdaOutputs: nil
    )
}
