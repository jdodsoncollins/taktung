import Testing
@testable import Taktung

struct SiteSearchTests {
    @Test func fullSiteHostnameFindsAnActionableProject() {
        let projects = buildDemoProjects()
        let project = projects.first { $0.id == DemoIDs.portfolio }!
        guard case .sites(let found) = searchLoadedSite(siteTitle(project), projects: projects, deployments: [], selectedProjectID: project.id) else {
            Issue.record("Expected selectable site results rather than a summary string"); return
        }
        #expect(found.map(\.id) == [project.id])
    }

    @Test func pastedHTTPSURLMatchesTheSameSite() {
        let project = buildDemoProjects().first!
        guard case .sites(let found) = searchLoadedSite("https://\(siteTitle(project))/", projects: [project], deployments: [], selectedProjectID: nil) else {
            Issue.record("Expected the site's URL to match"); return
        }
        #expect(found.first?.id == project.id)
    }

    @Test func stateQueriesReturnOnlyLoadedDeployments() {
        let projects = buildDemoProjects()
        let deployments = buildDemoDeployments(projectId: DemoIDs.portfolio)
        guard case .deployments(_, let failed) = searchLoadedSite("Failed deployments", projects: projects, deployments: deployments, selectedProjectID: DemoIDs.portfolio),
              case .deployments(_, let ready) = searchLoadedSite("Show ready deployments", projects: projects, deployments: deployments, selectedProjectID: DemoIDs.portfolio) else {
            Issue.record("Expected deployment results"); return
        }
        #expect(!failed.isEmpty && !ready.isEmpty)
        #expect(failed.allSatisfy { isFailedState($0.state) })
        #expect(ready.allSatisfy { $0.state == .ready })
        #expect(Set(failed.map(\.id)).isSubset(of: Set(deployments.map(\.id))))
    }

    @Test func selectedSiteIsRequiredForStateAndEnvironmentSearches() {
        for query in ["ready", "failed", "environment"] {
            guard case .chooseSite = searchLoadedSite(query, projects: buildDemoProjects(), deployments: [], selectedProjectID: nil) else {
                Issue.record("Must not imply account-wide deployment coverage"); continue
            }
        }
    }

    @Test func exactProjectNameWinsOverAStateKeyword() {
        var project = buildDemoProjects().first!
        project.name = "ready"
        guard case .sites(let found) = searchLoadedSite("ready", projects: [project], deployments: [], selectedProjectID: project.id) else {
            Issue.record("A project named ready should still be selectable"); return
        }
        #expect(found.first?.id == project.id)
    }

    @Test func partialQueriesAndUnknownQueriesStayDistinct() {
        let projects = buildDemoProjects()
        guard case .sites(let found) = searchLoadedSite("portfolio", projects: projects, deployments: [], selectedProjectID: nil) else {
            Issue.record("Partial site query should find its site"); return
        }
        #expect(!found.isEmpty)
        guard case .noMatch = searchLoadedSite("zzznomatches", projects: projects, deployments: [], selectedProjectID: nil) else {
            Issue.record("Unknown query must not fabricate a result"); return
        }
    }
}
