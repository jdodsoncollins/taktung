import Foundation
import Testing
@testable import Taktung

private final class StubVercelProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let path = request.url!.path
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
        let hasTeam = query.contains { $0.name == "teamId" && $0.value == "team_test" }
        let expectedMutation = request.value(forHTTPHeaderField: "X-Test-Expected-Path")
        let reads = ["/v9/projects/prj_test", "/v10/projects", "/v3/deployments/dpl_test/events"]
        let valid = hasTeam && (expectedMutation.map { path == $0 && request.httpMethod == "POST" }
            ?? (reads.contains(path) && request.httpMethod == "GET"))
        let body: String
        if path == "/v9/projects/prj_test" {
            body = #"{"targets":{"production":{"id":"dpl_current"}}}"#
        } else if path == "/v10/projects" {
            body = #"{"projects":[{"id":"prj_test","name":"test","targets":{"production":{"id":"dpl_current","state":"READY"}},"latestDeployments":[{"id":"dpl_new","state":"READY","target":"production","created":20}]}]}"#
        } else if path == "/v3/deployments/dpl_test/events" {
            body = #"[{"text":"Type error: Property is missing","created":2000},{"text":"API_KEY=synthetic-secret","created":1000}]"#
        } else { body = "" }
        let response = HTTPURLResponse(url: request.url!, statusCode: valid ? (expectedMutation != nil ? 201 : 200) : 400,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

struct VercelAPIMappingTests {
    private func api(expectedMutation: String? = nil) -> LiveVercelAPIClient {
        let config = URLSessionConfiguration.ephemeral
        if let expectedMutation { config.httpAdditionalHeaders = ["X-Test-Expected-Path": expectedMutation] }
        config.protocolClasses = [StubVercelProtocol.self]
        return LiveVercelAPIClient(tokenProvider: { "synthetic-token" }, session: URLSession(configuration: config))
    }

    @Test func promoteAndRollbackUseTheirOwnEndpointsWithTeamScope() async throws {
        try await api(expectedMutation: "/v10/projects/prj_test/promote/dpl_test")
            .promote(deploymentId: "dpl_test", projectId: "prj_test", teamId: "team_test")
        try await api(expectedMutation: "/v1/projects/prj_test/rollback/dpl_test")
            .rollback(deploymentId: "dpl_test", projectId: "prj_test", teamId: "team_test")
    }

    @Test func productionTrafficUsesCurrentTargetInsteadOfNewestBuild() async throws {
        let api = api()
        #expect(try await api.productionDeploymentID(projectId: "prj_test", teamId: "team_test") == "dpl_current")
        let projects = try await api.listProjects(teamId: "team_test")
        #expect(projects.first?.productionDeployment?.id == "dpl_current")
        #expect(projects.first?.latestDeployment?.id == "dpl_new")
    }

    @Test func logsAreRedactedAtTheAPIBoundary() async throws {
        let logs = try await api().getBuildLogLines(id: "dpl_test", teamId: "team_test", limit: 200)
        #expect(logs.count == 2)
        #expect(logs.first?.text == "[REDACTED]")
        #expect(logs.last?.text == "Type error: Property is missing")
    }
}
