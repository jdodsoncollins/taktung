import Foundation

protocol WebAnalyticsAPI: Sendable {
    func analyticsOverview(projectID: ProjectID, teamID: TeamID?, window: AnalyticsWindow) async throws -> AnalyticsOverview
    func analyticsSegments(projectID: ProjectID, teamID: TeamID?, dimension: AnalyticsDimension, window: AnalyticsWindow) async throws -> [AnalyticsSegment]
}

extension WebAnalyticsAPI {
    func analyticsOverview(projectID: ProjectID, teamID: TeamID?, window: AnalyticsWindow) async throws -> AnalyticsOverview {
        throw VercelAPIError(status: 501, detail: "Analytics unavailable for this connection.")
    }
    func analyticsSegments(projectID: ProjectID, teamID: TeamID?, dimension: AnalyticsDimension, window: AnalyticsWindow) async throws -> [AnalyticsSegment] {
        throw VercelAPIError(status: 501, detail: "Analytics unavailable for this connection.")
    }
}

final class WebAnalyticsClient: WebAnalyticsAPI, @unchecked Sendable {
    private let baseURL: URL
    private let tokenProvider: @Sendable () async throws -> String?
    private let session: URLSession

    init(baseURL: URL = AppConfig.vercelAPIBase, tokenProvider: @escaping @Sendable () async throws -> String?,
         session: URLSession = URLSession(configuration: .ephemeral)) {
        self.baseURL = baseURL; self.tokenProvider = tokenProvider; self.session = session
    }

    func analyticsOverview(projectID: ProjectID, teamID: TeamID?, window: AnalyticsWindow) async throws -> AnalyticsOverview {
        let total = try await query(projectID: projectID, teamID: teamID, window: window)
        let effective = try AnalyticsContract.window(total, within: window)
        let counts = try AnalyticsContract.counts(total["data"])
        let trend = try await query(projectID: projectID, teamID: teamID, window: effective, group: "day", limit: 32)
        let days = try AnalyticsContract.days(trend, window: effective)
        // Do not combine totals and a chart from different server-aligned periods.
        let sum = days.reduce(0.0) { $0 + Double($1.counts.pageviews) }
        guard sum == Double(counts.pageviews) else { throw AnalyticsContract.invalid() }
        return AnalyticsOverview(window: effective, counts: counts, days: days)
    }

    func analyticsSegments(projectID: ProjectID, teamID: TeamID?, dimension: AnalyticsDimension, window: AnalyticsWindow) async throws -> [AnalyticsSegment] {
        let raw = try await query(projectID: projectID, teamID: teamID, window: window, group: dimension.rawValue, limit: 10)
        return try AnalyticsContract.segments(raw, dimension: dimension, window: window)
    }

    private func query(projectID: ProjectID, teamID: TeamID?, window: AnalyticsWindow, group: String? = nil, limit: Int? = nil) async throws -> JSONValue {
        try Task.checkCancellation()
        guard let token = try await tokenProvider(), !token.isEmpty else { throw VercelAPIError(status: 401, detail: "Not connected.") }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let route = "v1/query/web-analytics/visits/\(group == nil ? "count" : "aggregate")"
        var parts = URLComponents(url: baseURL.appendingPathComponent(route), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "projectId", value: projectID),
                     URLQueryItem(name: "since", value: formatter.string(from: window.since)),
                     URLQueryItem(name: "until", value: formatter.string(from: window.until.addingTimeInterval(group == nil ? 0 : -0.001))),
                     URLQueryItem(name: "filter", value: "environment eq 'production'")]
        if let teamID { items.append(URLQueryItem(name: "teamId", value: teamID)) }
        // Vercel reads `by` as a plain dimension name (repeat the item for two). A JSON array is rejected with 400.
        if let group { items.append(URLQueryItem(name: "by", value: group)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        parts.queryItems = items
        var request = URLRequest(url: parts.url!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let (bytes, response) = try await session.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 2_097_152 else { throw AnalyticsContract.invalid() }
            data.append(byte)
        }
        guard (200..<300).contains(status) else {
            let parsed = (try? JSONSerialization.jsonObject(with: data)).map { JSONValue($0) }
            let message = parsed?["error"]?["message"]?.string ?? parsed?["message"]?.string
            throw VercelAPIError(status: status, detail: message.map { inspectionText($0, limit: 240) } ?? "Analytics request failed (\(status)).")
        }
        return JSONValue(try JSONSerialization.jsonObject(with: data))
    }
}
