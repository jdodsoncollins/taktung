import Testing
@testable import Taktung

struct DemoModeTests {
    @Test func parsesTruthyFlags() {
        #expect(DemoMode.demoModeEnabled("1"))
        #expect(DemoMode.demoModeEnabled("true"))
        #expect(DemoMode.demoModeEnabled("YES"))
        #expect(!DemoMode.demoModeEnabled("0"))
        #expect(!DemoMode.demoModeEnabled(nil))
        #expect(!DemoMode.demoModeEnabled("no"))
    }

    @Test func fixturesHaveNoIdentifyingCopy() {
        let projects = buildDemoProjects()
        #expect(projects.count == 4)
        for project in projects {
            #expect(!demoHasIdentifyingCopy(project.name))
            #expect(!demoHasIdentifyingCopy(siteTitle(project)))
            #expect(project.needsAttention == false)
        }
        let deploys = buildDemoDeployments(projectId: DemoIDs.portfolio)
        #expect(deploys.count == 19)
        #expect(deploys.filter { $0.state == .error }.count == 3)
        #expect(deploys.filter { $0.target == .production }.count == 16)
        for deploy in deploys {
            #expect(!demoHasIdentifyingCopy(deploymentTitle(deploy)))
        }
        #expect(demoUser.email == nil)
    }

    @Test func demoClientDoesNotMutate() async {
        let client = DemoAPIClient()
        await #expect(throws: VercelAPIError.self) {
            try await client.redeploy(
                deploymentId: "dpl_demo_portfolio_0",
                projectId: DemoIDs.portfolio,
                teamId: DemoIDs.team,
                target: .production
            )
        }
    }
}
