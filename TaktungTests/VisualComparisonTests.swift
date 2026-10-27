import Foundation
import Testing
@testable import Taktung

struct VisualComparisonTests {
    @Test func rejectsExternalURLsQueriesFragmentsAndTraversal() throws {
        #expect(try comparisonRoute(" /about/team ") == "/about/team")
        #expect(try comparisonRoute("/") == "/")
        for invalid in ["https://evil.example", "//evil.example", "/?token=secret", "/#secret", "/../admin", "/%2e%2e/admin", "/\\evil"] {
            #expect(throws: VisualComparisonError.self) { try comparisonRoute(invalid) }
        }
    }

    @Test func bindsRoutesToReadyDeploymentAndDropsQueries() throws {
        var deploy = buildDemoDeployments(projectId: DemoIDs.portfolio).first!
        deploy.url = "https://candidate.vercel.app/?unsafe=secret"
        #expect(try comparisonURL(deployment: deploy, route: "/about").absoluteString == "https://candidate.vercel.app/about")
        deploy.state = .building
        #expect(throws: VisualComparisonError.self) { try comparisonURL(deployment: deploy, route: "/") }
        deploy.state = .ready
        deploy.url = "https://user:password@candidate.vercel.app"
        #expect(throws: VisualComparisonError.self) { try comparisonURL(deployment: deploy, route: "/") }
    }

    @Test func referenceSelectionPrefersProductionAndExcludesCandidateFailuresAndDuplicates() {
        let project = buildDemoProjects().first { $0.id == DemoIDs.portfolio }!
        let deploys = buildDemoDeployments(projectId: DemoIDs.portfolio)
        let candidate = deploys[1]
        let references = comparisonBaselines(project: project, deployments: deploys + deploys, candidateID: candidate.id)
        #expect(references.first?.id == project.productionDeployment?.id)
        #expect(!references.contains { $0.id == candidate.id || $0.state != .ready })
        #expect(Set(references.map(\.id)).count == references.count)
    }
}
