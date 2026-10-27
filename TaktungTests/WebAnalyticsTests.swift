import Foundation
import Testing
@testable import Taktung

private let analyticsStart = "2026-10-13T00:00:00.000Z"
private let analyticsEnd = "2026-10-20T00:00:00.000Z"

private final class AnalyticsStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let q = Dictionary(uniqueKeysWithValues: URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        let aggregate = request.url!.path.hasSuffix("aggregate")
        let valid = request.httpMethod == "GET" && request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-analytics-token"
            && q["projectId"] == "prj_analytics" && q["teamId"] == "team_analytics"
            && q["filter"] == "environment eq 'production'" && q["since"] == analyticsStart
            && q["until"] == (aggregate ? "2026-10-19T23:59:59.999Z" : analyticsEnd)
        let forced = request.value(forHTTPHeaderField: "X-Test-Status").flatMap(Int.init)
        let status = forced ?? (valid ? 200 : 400)
        var query: [String: Any] = ["since": analyticsStart, "until": analyticsEnd]
        if request.value(forHTTPHeaderField: "X-Test-Misaligned") != nil, aggregate { query["until"] = "2026-10-21T00:00:00.000Z" }
        let payload: Any
        if !aggregate { payload = ["visitors": 67, "pageviews": 153] }
        else if q["by"] == "day", q["limit"] == "32" {
            payload = [["timestamp": analyticsStart, "visitors": 67, "pageviews": 153]]
        } else if q["by"] == "requestPath", q["limit"] == "10" {
            payload = [["requestPath": "/", "visitors": 50, "pageviews": 110], ["requestPath": "Others", "visitors": 20, "pageviews": 43]]
        } else { payload = NSNull() }
        let data = try! JSONSerialization.data(withJSONObject: ["version": 1, "query": query, "data": payload])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

struct WebAnalyticsTests {
    private var window: AnalyticsWindow {
        AnalyticsWindow(since: AnalyticsContract.date(.string(analyticsStart))!, until: AnalyticsContract.date(.string(analyticsEnd))!)
    }
    private func client(status: Int? = nil, misaligned: Bool = false) -> WebAnalyticsClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AnalyticsStubProtocol.self]
        if let status { config.httpAdditionalHeaders = ["X-Test-Status": String(status)] }
        if misaligned { config.httpAdditionalHeaders = ["X-Test-Misaligned": "true"] }
        return WebAnalyticsClient(tokenProvider: { "synthetic-analytics-token" }, session: URLSession(configuration: config))
    }

    @Test func reportingPeriodsUseCompletedUTCDaysRegardlessOfLocalTimezone() {
        let now = AnalyticsContract.date(.string("2026-10-20T22:21:36Z"))!
        #expect(AnalyticsPeriod.week.window(now: now) == window)
        #expect(AnalyticsPeriod.month.window(now: now).until == window.until)
        #expect(AnalyticsPeriod.month.window(now: now).until.timeIntervalSince(AnalyticsPeriod.month.window(now: now).since) == 30 * 86_400)
    }

    @Test func liveTransportUsesScopedReadOnlyQueriesAndInclusiveAggregateCorrection() async throws {
        let result = try await client().analyticsOverview(projectID: "prj_analytics", teamID: "team_analytics", window: window)
        #expect(result.counts == AnalyticsCounts(visitors: 67, pageviews: 153))
        #expect(result.days.reduce(0) { $0 + $1.counts.pageviews } == result.counts.pageviews)
        #expect(result.window == window)
        let segments = try await client().analyticsSegments(projectID: "prj_analytics", teamID: "team_analytics", dimension: .pages, window: window)
        #expect(segments.map(\.key) == ["/", "Others"])
        #expect(segments.reduce(0) { $0 + $1.counts.visitors } == 70) // deliberately not the overall visitor total
    }

    @Test func forbiddenOrRateLimitedTrafficNeverBecomesZero() async {
        for status in [401, 403, 404, 429, 500] {
            do {
                _ = try await client(status: status).analyticsOverview(projectID: "prj_analytics", teamID: "team_analytics", window: window)
                Issue.record("Access failure became a successful overview")
            } catch { #expect((error as? VercelAPIError)?.status == status) }
        }
    }

    @Test func misalignedChartIsRejectedInsteadOfCombinedWithTotals() async {
        await #expect(throws: (any Error).self) {
            try await client(misaligned: true).analyticsOverview(projectID: "prj_analytics", teamID: "team_analytics", window: window)
        }
    }

    @Test func malformedCountsCannotMasqueradeAsEmptyTraffic() throws {
        for raw in [["visitors": -1, "pageviews": 0], ["visitors": 1.5, "pageviews": 2], ["visitors": 1]] {
            #expect(throws: (any Error).self) { try AnalyticsContract.counts(JSONValue(raw)) }
        }
        #expect(try AnalyticsContract.counts(JSONValue(["visitors": 0, "pageviews": 0])) == .init(visitors: 0, pageviews: 0))
    }

    @Test func duplicateAndOutsideWindowDaysAreRejected() {
        let row: [String: Any] = ["timestamp": analyticsStart, "visitors": 1, "pageviews": 2]
        let query = ["since": analyticsStart, "until": analyticsEnd]
        #expect(throws: (any Error).self) { try AnalyticsContract.days(JSONValue(["query": query, "data": [row, row]]), window: window) }
        #expect(throws: (any Error).self) {
            try AnalyticsContract.days(JSONValue(["query": query, "data": [["timestamp": analyticsEnd, "visitors": 1, "pageviews": 2]]]), window: window)
        }
    }

    @Test func dimensionsConcealQueryStringsAndHandleDirectReferrers() {
        #expect(AnalyticsDimension.pages.label("/account?token=concealed#secret") == "/account")
        #expect(AnalyticsDimension.referrers.label("") == "Direct / unknown")
        #expect(AnalyticsDimension.pages.label("Others") == "Others")
    }

    @Test func otherAppsHaveVerifiedDestinationsAndExcludeThisApp() {
        #expect(AppConfig.otherApps.map(\.id) == ["codable", "tabforge", "paper-and-grain"])
        #expect(Set(AppConfig.otherApps.map(\.storeID)).count == 3)
        #expect(AppConfig.otherApps.allSatisfy { $0.detailURL.host == "www.jeremycollins.net" && $0.storeURL.host == "apps.apple.com" })
    }
}
