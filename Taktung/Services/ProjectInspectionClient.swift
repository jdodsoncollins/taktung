import Foundation

protocol ProjectInspectionAPI: Sendable {
    func inspect(_ tool: ProjectTool, projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID?) async throws -> InspectionResult
    func runtimeLogs(projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID) -> AsyncThrowingStream<RuntimeLogEntry, Error>
}

extension ProjectInspectionAPI {
    func inspect(_ tool: ProjectTool, projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID?) async throws -> InspectionResult {
        throw VercelAPIError(status: 501, detail: "This connection does not support project inspection.")
    }
    func runtimeLogs(projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID) -> AsyncThrowingStream<RuntimeLogEntry, Error> {
        AsyncThrowingStream { $0.finish(throwing: VercelAPIError(status: 501, detail: "Runtime logs unavailable.")) }
    }
}

final class ProjectInspectionClient: ProjectInspectionAPI, @unchecked Sendable {
    private let baseURL: URL
    private let tokenProvider: @Sendable () async throws -> String?
    private let session: URLSession
    init(baseURL: URL = AppConfig.vercelAPIBase, tokenProvider: @escaping @Sendable () async throws -> String?,
         session: URLSession = URLSession(configuration: .ephemeral)) {
        self.baseURL = baseURL; self.tokenProvider = tokenProvider; self.session = session
    }

    private func request(_ path: String, teamID: TeamID?, query: [String: String] = [:]) async throws -> URLRequest {
        guard let token = try await tokenProvider(), !token.isEmpty else {
            throw VercelAPIError(status: 401, detail: "Not connected.")
        }
        var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var query = query
        if let teamID { query["teamId"] = teamID }
        parts.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: parts.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        return request
    }

    func inspect(_ tool: ProjectTool, projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID?) async throws -> InspectionResult {
        let path: String
        var query: [String: String] = ["limit": "50"]
        switch tool {
        case .activity:
            path = "v3/events"; query["projectIds"] = projectID; query["withPayload"] = "true"
        case .domains: path = "v9/projects/\(projectID)/domains"
        case .checks:
            guard let deploymentID else { throw VercelAPIError(status: 404, detail: "No deployment selected.") }
            path = "v1/deployments/\(deploymentID)/checks"; query = [:]
        case .crons: path = "v9/projects/\(projectID)"; query = [:]
        case .flags: path = "v1/projects/\(projectID)/feature-flags/flags"
        }
        let request = try await request(path, teamID: teamID, query: query)
        // Bound the wire response before decoding; never read unbounded activity payloads.
        let (bytes, response) = try await session.bytes(for: request)
        try validate(response)
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 2_097_152 else { throw VercelAPIError(status: nil, detail: "Evidence response exceeded its size limit.") }
            data.append(byte)
        }
        let raw = JSONValue(try JSONSerialization.jsonObject(with: data))
        return try mapInspection(tool, raw: raw)
    }

    func runtimeLogs(projectID: ProjectID, teamID: TeamID?, deploymentID: DeploymentID) -> AsyncThrowingStream<RuntimeLogEntry, Error> {
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(500)) { continuation in
            let task = Task {
                do {
                    var request = try await self.request("v1/projects/\(projectID)/deployments/\(deploymentID)/runtime-logs", teamID: teamID)
                    request.timeoutInterval = 60
                    request.setValue("application/stream+json", forHTTPHeaderField: "Accept")
                    let (bytes, response) = try await self.session.bytes(for: request)
                    try self.validate(response)
                    var decoder = RuntimeLogDecoder()
                    var byteCount = 0
                    var records = 0
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        byteCount += 1
                        if byteCount > 2_097_152 { break }
                        if let entry = try decoder.append(byte) {
                            continuation.yield(entry); records += 1
                            if records >= 500 { break }
                        }
                    }
                    if records < 500, byteCount <= 2_097_152, let last = try decoder.finish() { continuation.yield(last) }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { @Sendable _ in task.cancel() }
        }
    }

    private func validate(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            // Do not expose arbitrary error bodies (which may contain values or credentials).
            throw VercelAPIError(status: status, detail: "Vercel request failed (\(status)).")
        }
    }
}

func mapInspection(_ tool: ProjectTool, raw: JSONValue) throws -> InspectionResult {
    let rows: [JSONValue]
    let empty: String
    let note: String
    switch tool {
    case .activity:
        guard let values = raw["events"]?.array else { throw VercelAPIError.decodeFailed("activity", "missing events") }
        rows = values; empty = "No project activity returned"; note = "Up to 50 recent Vercel events. This is separate from your local Field Log."
    case .domains:
        guard let values = raw["domains"]?.array else { throw VercelAPIError.decodeFailed("domains", "missing domains") }
        rows = values; empty = "No domains returned"; note = "Up to 50 domain records. Verification is ownership evidence, not an uptime or TLS test."
    case .checks:
        guard let values = raw["checks"]?.array else { throw VercelAPIError.decodeFailed("checks", "missing checks") }
        rows = values; empty = "No checks configured for this deployment"; note = "Results reported by Vercel for the selected deployment. READY does not imply that checks passed."
    case .crons:
        guard raw["id"]?.string != nil else { throw VercelAPIError.decodeFailed("cron jobs", "missing project") }
        rows = raw["crons"]?["definitions"]?.array ?? []; empty = "No cron jobs configured"
        note = "Schedules use UTC. Configuration is not execution history. Query strings are concealed."
    case .flags:
        guard let values = raw["data"]?.array else { throw VercelAPIError.decodeFailed("feature flags", "missing flags") }
        rows = values; empty = "No feature flags returned"; note = "Up to 50 flag names. SDK keys and targeting values are concealed."
    }
    let mapped = rows.prefix(tool == .checks ? 100 : 50).enumerated().compactMap { index, value -> InspectionRow? in
        switch tool {
        case .activity:
            guard let id = value["id"]?.string else { return nil }
            let type = value["type"]?.string ?? ""
            let category = type.contains("deploy") ? "Deployments" : type.contains("alias") || type.contains("domain") ? "Domains" : "Project"
            let titles = ["deployment": "Deployment created", "deployment-ready": "Deployment ready", "deployment-error": "Deployment failed",
                          "aliases-assigned": "Aliases assigned", "alias": "Alias updated", "project-created": "Project created",
                          "project-removed": "Project removed", "env-variable-add": "Environment variable added",
                          "env-variable-edit": "Environment variable updated", "env-variable-remove": "Environment variable removed"]
            let title = titles[type] ?? (category == "Deployments" ? "Deployment activity" : category == "Domains" ? "Domain or alias update" : "Project update")
            let actor = value["user"]?["username"]?.string ?? value["principal"]?["username"]?.string
            // Only allow event-type metadata; raw payloads can contain secrets.
            let safeType = type.allSatisfy { $0.isLetter || $0.isNumber || "-_".contains($0) } ? type : "event"
            let target = value["payload"]?["target"]?.string.flatMap { ["production", "preview", "development"].contains($0) ? $0 : nil }
            return .init(id: id, title: title, detail: [actor.map { inspectionText($0, limit: 80) }, target, String(safeType.prefix(80))].compactMap { $0 }.joined(separator: " · "),
                         date: inspectionDate(value["created"] ?? value["createdAt"]), category: category)
        case .domains:
            guard let name = value["name"]?.string else { return nil }
            let verified = value["verified"]?.bool
            return .init(id: name, title: inspectionText(name), detail: value["redirect"]?.string.map { "Redirects to \(inspectionPath($0))" } ?? "Project domain",
                         state: verified == true ? "Verified" : verified == false ? "Verification needed" : "Verification unavailable",
                         tone: verified == true ? .ready : verified == false ? .warning : .neutral)
        case .checks:
            guard let id = value["id"]?.string else { return nil }
            let (state, tone) = checkPresentation(status: value["status"]?.string, conclusion: value["conclusion"]?.string)
            return .init(id: id, title: inspectionText(value["name"]?.string ?? "Deployment check"),
                detail: value["blocking"]?.bool.map { $0 ? "Blocking check" : "Non-blocking check" } ?? "Blocking behavior unavailable", state: state, tone: tone,
                date: inspectionDate(value["completedAt"] ?? value["updatedAt"]))
        case .crons:
            return .init(id: String(index), title: inspectionPath(value["path"]?.string ?? "/"), detail: inspectionText(value["schedule"]?.string ?? "Schedule unavailable"),
                         state: raw["crons"]?["disabledAt"]?.double != nil ? "Disabled" : "Configured")
        case .flags:
            guard let name = value["slug"]?.string ?? value["key"]?.string ?? value["name"]?.string else { return nil }
            return .init(id: value["id"]?.string ?? name, title: inspectionText(name), detail: inspectionText(value["kind"]?.string ?? "Feature flag"),
                         state: value["state"]?.string == "archived" ? "Archived" : "Configured")
        }
    }
    if !rows.isEmpty && mapped.isEmpty { throw VercelAPIError.decodeFailed(tool.title, "unrecognized records") }
    var seen = Set<String>()
    return InspectionResult(rows: mapped.filter { seen.insert($0.id).inserted }, note: note, emptyTitle: empty)
}
