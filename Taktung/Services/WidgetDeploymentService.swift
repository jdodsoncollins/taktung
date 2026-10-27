import Foundation

/// One bounded GET for one widget scope. The widget has no deployment mutation API.
struct WidgetDeploymentService: Sendable {
    enum Failure: Error { case unauthorized, unavailable, invalidResponse }
    var session: URLSession = .shared

    func refresh(_ snapshot: WidgetDeploymentSnapshot, token: String,
                 now: Date = Date()) async throws -> WidgetDeploymentSnapshot {
        guard snapshot.source == .live, snapshot.isValid, !token.isEmpty else { throw Failure.unauthorized }
        let request = Self.request(snapshot, token: token)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw Failure.invalidResponse }
        if response.statusCode == 401 || response.statusCode == 403 { throw Failure.unauthorized }
        guard response.statusCode == 200 else { throw Failure.unavailable }
        return try Self.decode(data, for: snapshot, now: now)
    }

    static func request(_ snapshot: WidgetDeploymentSnapshot, token: String) -> URLRequest {
        var url = URLComponents(url: AppConfig.vercelAPIBase.appendingPathComponent("v7/deployments"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "limit", value: String(WidgetDeploymentSnapshot.sampleLimit))]
        if snapshot.projectID != WidgetAccountContext.allProjectsID {
            url.queryItems?.append(URLQueryItem(name: "projectId", value: snapshot.projectID))
        }
        if let team = snapshot.teamID { url.queryItems?.append(URLQueryItem(name: "teamId", value: team)) }
        var request = URLRequest(url: url.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func decode(_ data: Data, for snapshot: WidgetDeploymentSnapshot,
                       now: Date = Date()) throws -> WidgetDeploymentSnapshot {
        guard data.count <= 2_000_000 else { throw Failure.invalidResponse }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        let deployments = try envelope.deployments.prefix(WidgetDeploymentSnapshot.sampleLimit).map { raw in
            guard let id = raw.uid ?? raw.id, !id.isEmpty,
                  let created = raw.created ?? raw.createdAt, created.isFinite, created > 0,
                  snapshot.projectID == WidgetAccountContext.allProjectsID || raw.projectId == nil || raw.projectId == snapshot.projectID else { throw Failure.invalidResponse }
            return VercelDeploymentSummary(id: id, name: raw.name ?? snapshot.projectName,
                state: DeploymentState.map(raw.readyState ?? raw.state),
                target: raw.target.flatMap(DeploymentTarget.init(rawValue:)), createdAt: created, meta: GitMeta())
        }
        return .make(projectID: snapshot.projectID, projectName: snapshot.projectName,
                     accountID: snapshot.accountID, teamID: snapshot.teamID, revision: snapshot.revision,
                     source: .live, deployments: deployments, now: now)
    }

    private struct Envelope: Decodable { var deployments: [Deployment] }
    private struct Deployment: Decodable {
        var uid: String?
        var id: String?
        var projectId: String?
        var name: String?
        var readyState: String?
        var state: String?
        var target: String?
        var created: Double?
        var createdAt: Double?
    }
}
