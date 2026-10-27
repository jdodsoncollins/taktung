import Foundation
import Testing
@testable import Taktung

private final class InspectionStubProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let url = request.url!
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let valid = query["teamId"] == "team_test" && request.httpMethod == "GET"
            && request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-token"
        var body = "{}"
        switch url.path {
        case "/v3/events":
            if query["projectIds"] == "prj_test", query["limit"] == "50" { body = #"{"events":[{"id":"event","type":"deployment","created":1000}]}"# }
        case "/v9/projects/prj_test/domains": body = #"{"domains":[{"name":"site.example","verified":true}]}"#
        case "/v1/deployments/dpl_test/checks": body = #"{"checks":[]}"#
        case "/v9/projects/prj_test": body = #"{"id":"prj_test","crons":{"definitions":[]},"env":[{"value":"must-never-be-rendered"}]}"#
        case "/v1/projects/prj_test/feature-flags/flags": body = #"{"data":[{"id":"flag","slug":"checkout","variants":[{"value":"must-never-be-rendered"}]}],"pagination":{"next":null}}"#
        case "/v1/projects/prj_test/deployments/dpl_test/runtime-logs":
            body = "{\"source\":\"delimiter\"}\n" + #"{"rowId":"row","source":"serverless","level":"error","message":"API_KEY=must-never-be-rendered","requestPath":"/api/catalog?token=concealed","responseStatusCode":503,"timestampInMs":1000}"# + "\n"
        default: break
        }
        let forcedStatus = request.value(forHTTPHeaderField: "X-Test-Status").flatMap(Int.init)
        let response = HTTPURLResponse(url: url, statusCode: forcedStatus ?? (valid ? 200 : 400), httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        // Split records and UTF-8 sequences across transport chunks.
        let bytes = Array(body.utf8)
        for offset in stride(from: 0, to: bytes.count, by: 7) {
            client?.urlProtocol(self, didLoad: Data(bytes[offset..<min(bytes.count, offset + 7)]))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}

struct ProjectInspectionTests {
    @Test func deploymentSearchCombinesScopeTargetStateAndCommitMetadata() {
        var production = buildDemoDeployments(projectId: DemoIDs.portfolio)[0]
        production.target = .production
        production.state = .ready
        production.meta.githubCommitMessage = "Improve rendering speed"
        production.meta.githubCommitSha = "abc123456789"
        var preview = production
        preview.id = "preview"; preview.target = nil; preview.state = .error
        #expect(searchDeployments([production, preview], filter: .failed, target: .production, query: "").isEmpty)
        #expect(searchDeployments([production, preview], filter: .failed, target: .preview, query: " ABC123 ").map(\.id) == ["preview"])
        #expect(searchDeployments([production, preview], filter: .all, target: .production, query: "rendering").map(\.id) == [production.id])
        #expect(searchDeployments([production, preview], filter: .all, target: .all, query: "not found").isEmpty)
    }
    private func client(status: Int? = nil) -> ProjectInspectionClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [InspectionStubProtocol.self]
        if let status { config.httpAdditionalHeaders = ["X-Test-Status": String(status)] }
        return ProjectInspectionClient(tokenProvider: { "synthetic-token" }, session: URLSession(configuration: config))
    }

    @Test func readOnlyToolsUseTheirOwnRoutesAndWorkspaceScope() async throws {
        for tool in ProjectTool.allCases {
            let result = try await client().inspect(tool, projectID: "prj_test", teamID: "team_test", deploymentID: "dpl_test")
            #expect(!result.rows.map(\.detail).joined().contains("must-never-be-rendered"))
            #expect(result.fetchedAt <= Date())
        }
    }

    @Test func runtimeStreamParsesSplitRecordsAndConcealsCredentials() async throws {
        var records: [RuntimeLogEntry] = []
        for try await record in client().runtimeLogs(projectID: "prj_test", teamID: "team_test", deploymentID: "dpl_test") { records.append(record) }
        #expect(records.count == 1)
        #expect(records.first?.isError == true)
        #expect(records.first?.message == "[REDACTED]")
        #expect(records.first?.path == "/api/catalog")
    }

    @Test func accessFailureIsNotAnEmptySuccessfulResult() async {
        do {
            _ = try await client(status: 403).inspect(.domains, projectID: "prj_test", teamID: "team_test", deploymentID: nil)
            Issue.record("Forbidden evidence must throw")
        } catch {
            #expect((error as? VercelAPIError)?.status == 403)
            #expect(InspectionFailure(error).title == "Access unavailable")
        }
    }

    @Test func emptyChecksDoNotClaimPassingAndMissingPayloadIsAnError() throws {
        let result = try mapInspection(.checks, raw: JSONValue(["checks": []]))
        #expect(result.rows.isEmpty)
        #expect(result.emptyTitle == "No checks configured for this deployment")
        #expect(throws: (any Error).self) { try mapInspection(.checks, raw: JSONValue(["unexpected": []])) }
        #expect(throws: (any Error).self) { try mapInspection(.domains, raw: JSONValue(["domains": [["unexpected": true]]])) }
        #expect(checkPresentation(status: "completed", conclusion: "failed").0 == "Failed")
        #expect(checkPresentation(status: "running", conclusion: "succeeded").0 == "Running")
        #expect(checkPresentation(status: "new-status", conclusion: nil).0 == "Status unavailable")
        #expect(checkPresentation(status: "completed", conclusion: nil).0 == "Result unavailable")
    }

    @Test func activityAllowlistExcludesRawPayloadAndDeduplicatesIdentity() throws {
        let event: [String: Any] = ["id": "same", "type": "env-variable-edit", "text": "must-never-be-rendered",
                                  "payload": ["value": "must-never-be-rendered", "secret": "must-never-be-rendered"], "user": ["username": "alex"]]
        let result = try mapInspection(.activity, raw: JSONValue(["events": [event, event]]))
        #expect(result.rows.count == 1)
        #expect(result.rows.first?.title == "Environment variable updated")
        #expect(!result.rows.map { $0.title + $0.detail }.joined().contains("must-never-be-rendered"))
    }

    @Test func ownershipAndSchedulesNeverImplyUptimeOrExecution() throws {
        let domains = try mapInspection(.domains, raw: JSONValue(["domains": [["name": "site.example", "verified": false]]]))
        #expect(domains.rows.first?.state == "Verification needed")
        let crons = try mapInspection(.crons, raw: JSONValue(["id": "project", "crons": ["disabledAt": 1000, "definitions": [["path": "/api/task?secret=concealed", "schedule": "0 4 * * *"]]]]))
        #expect(crons.rows.first?.title == "/api/task")
        #expect(crons.rows.first?.state == "Disabled")
    }

    @Test func runtimeDecoderHandlesUTF8SSEFinalRecordsAndRejectsOversizedRecords() throws {
        let raw = #"data: {"rowId":"one","message":"Déploy ✓","level":"info"}"#
        var decoder = RuntimeLogDecoder()
        for byte in raw.utf8 { #expect(try decoder.append(byte) == nil) }
        #expect(try decoder.finish()?.message == "Déploy ✓")
        #expect(try decoder.append(10) == nil)
        for _ in 0..<RuntimeLogDecoder.maximumRecordBytes { _ = try decoder.append(65) }
        #expect(throws: (any Error).self) { try decoder.append(65) }
    }

    @Test func logSearchCombinesErrorFilterWithTextAndRetainsStableLineIdentity() {
        let logs = [BuildLogLine(text: "compile start", type: "stdout"), BuildLogLine(text: "Type error: missing name", type: "stderr"), BuildLogLine(text: "request failed", type: "stdout")]
        #expect(filterBuildLogs(logs, query: " MISSING ", errorsOnly: true).map(\.id) == [1])
        #expect(filterBuildLogs(logs, query: "compile", errorsOnly: true).isEmpty)
        #expect(filterBuildLogs(logs, query: "", errorsOnly: true).count == 2)
    }

    @Test func enhancedRedactionKeepsCompilerTextAndRemovesANSIAndQueryCredentials() {
        for value in ["apiKey=must-never-be-rendered", "password: 'must-never-be-rendered'", "https://example.com/api?credential=must-never-be-rendered", "\"client_secret\": \"must-never-be-rendered\""] {
            #expect(!redactBuildLog(value).contains("must-never-be-rendered"))
        }
        #expect(redactBuildLog("\u{1B}[31mType error: missing name\u{1B}[0m") == "Type error: missing name")
    }
}
