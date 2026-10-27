import Foundation
import Testing
@testable import Taktung

/// Answers `/v7/deployments` only when the request carries exactly the expected
/// filters. It deliberately returns one record that ignores them.
private final class DeploymentSearchStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
        let sent = Set(items.map { "\($0.name)=\($0.value ?? "")" })
        let expected = Set((request.value(forHTTPHeaderField: "X-Test-Expected-Query") ?? "").split(separator: "&").map(String.init))
        let valid = request.url!.path == "/v7/deployments" && request.httpMethod == "GET" && sent == expected
        let body = #"""
            {"deployments":[
              {"uid":"dpl_match","readyState":"READY","target":"production","created":2000,
               "meta":{"githubCommitRef":"main","githubCommitMessage":"Fix analytics totals"}},
              {"uid":"dpl_ignored_filter","readyState":"ERROR","target":"production","created":1000,
               "meta":{"githubCommitRef":"main","githubCommitMessage":"Fix analytics chart"}}
            ],"pagination":{"count":2,"next":null}}
            """#
        let response = HTTPURLResponse(url: request.url!, statusCode: valid ? 200 : 400, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data((valid ? body : #"{"error":{"message":"unexpected query"}}"#).utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

struct DeploymentSearchAPITests {
    private func api(expecting query: String) -> LiveVercelAPIClient {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = ["X-Test-Expected-Query": query]
        config.protocolClasses = [DeploymentSearchStub.self]
        return LiveVercelAPIClient(tokenProvider: { "synthetic-token" }, session: URLSession(configuration: config))
    }

    @Test func filtersRunOnVercelAndAreCheckedAgainOnTheDevice() async throws {
        let api = api(expecting: "projectId=prj_test&teamId=team_test&limit=20&state=READY&target=production&branch=main")
        let found = try await api.searchDeployments(projectId: "prj_test", teamId: "team_test",
                                                    query: DeploymentQuery(states: [.ready], target: .production, branch: "main"))
        #expect(found.map(\.id) == ["dpl_match"])
    }

    @Test func commitTextWidensTheServerWindowAndMatchesLocally() async throws {
        let api = api(expecting: "projectId=prj_test&teamId=team_test&limit=100")
        let found = try await api.searchDeployments(projectId: "prj_test", teamId: "team_test",
                                                    query: DeploymentQuery(text: "analytics chart"))
        #expect(found.map(\.id) == ["dpl_ignored_filter"])
    }

    @Test func unexpectedFiltersSurfaceAsErrorsNotEmptyResults() async {
        let api = api(expecting: "projectId=prj_test&limit=20")
        await #expect(throws: VercelAPIError.self) {
            try await api.searchDeployments(projectId: "prj_test", teamId: "team_test", query: DeploymentQuery(states: [.ready]))
        }
    }
}
