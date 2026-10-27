import Foundation
import Testing
@testable import Taktung

struct SiteSearchTests {
    private let projects = buildDemoProjects()
    private let selected = DemoIDs.portfolio

    private func deployments(_ text: String, selected: ProjectID? = DemoIDs.portfolio) -> (DeploymentQuery, [String])? {
        let result = planSiteSearch(text, projects: projects, selectedProjectID: selected)
        guard case .deployments(let query) = result.plan else { return nil }
        return (query, result.unresolved)
    }

    @Test func fullSiteHostnameFindsAnActionableProject() {
        let project = projects.first { $0.id == DemoIDs.portfolio }!
        guard case .sites(let found) = planSiteSearch(siteTitle(project), projects: projects, selectedProjectID: project.id).plan else {
            Issue.record("Expected selectable site results rather than a summary string"); return
        }
        #expect(found.map(\.id) == [project.id])
    }

    @Test func pastedHTTPSURLMatchesTheSameSite() {
        let project = projects.first!
        guard case .sites(let found) = planSiteSearch("https://\(siteTitle(project))/", projects: [project], selectedProjectID: nil).plan else {
            Issue.record("Expected the site's URL to match"); return
        }
        #expect(found.first?.id == project.id)
    }

    @Test func successfulDeploymentsMeansReadyWithoutTheModel() throws {
        let (query, unresolved) = try #require(deployments("successful deployments"))
        #expect(query.states == [.ready])
        #expect(unresolved.isEmpty)
        #expect(query.title == "Ready deployments")
        for phrase in ["succeeded deploys", "passing builds", "green deployments", "what shipped", "Ready deployments"] {
            #expect(deployments(phrase)?.0.states == [.ready], "\(phrase)")
        }
    }

    @Test func naturalPhrasesMapToVercelFilters() throws {
        let failed = try #require(deployments("failed preview builds yesterday"))
        #expect(failed.0.states == DeploymentQuery.failedStates)
        #expect(failed.0.target == .preview)
        #expect(failed.0.window == .yesterday)
        #expect(failed.1.isEmpty)

        let latest = try #require(deployments("last successful deploy on main"))
        #expect(latest.0.states == [.ready])
        #expect(latest.0.branch == "main")
        #expect(latest.0.limit == 1)
        #expect(latest.0.title == "Latest ready deployment")

        let production = try #require(deployments("production deploys in the last 24 hours"))
        #expect(production.0.target == .production)
        #expect(production.0.window == .lastHours(24))

        #expect(deployments("last 5 deploys")?.0.limit == 5)
        #expect(deployments("deploys from the last 5 days")?.0.window == .lastDays(5))
        #expect(deployments("deploys this week")?.0.window == .thisWeek)
        #expect(deployments("what's building right now")?.0.states == DeploymentQuery.inFlightStates)
        #expect(deployments("canceled deployments")?.0.states == [.canceled])
        #expect(deployments("deploys on feature/search-fix")?.0.branch == "feature/search-fix")
        #expect(deployments("hotfix branch deploys")?.0.branch == "hotfix")
        #expect(deployments("deploys on Feature/Login")?.0.branch == "Feature/Login", "Branch filters are exact on Vercel")
        #expect(deployments("ready deploys on Master")?.0.branch == "master")
        #expect(deployments("deploy 3f2a91c")?.0.sha == "3f2a91c")
        #expect(deployments(#"deploys "fix analytics""#)?.0.text == "fix analytics")
    }

    @Test func negationDoesNotInvertTheRequest() throws {
        let (query, _) = try #require(deployments("deployments that didn't fail"))
        #expect(!query.states.contains(.error))
        #expect(query.states.contains(.ready))
    }

    @Test func unknownWordsAreKeptForTheModelAndFallBackToCommitText() throws {
        let result = planSiteSearch("successful deploys tuesday", projects: projects, selectedProjectID: selected)
        #expect(result.unresolved == ["tuesday"])
        #expect(result.needsModel)
        guard case .deployments(let query) = result.plan else { Issue.record("Expected deployments"); return }
        #expect(query.states == [.ready])
        #expect(query.text == "tuesday")
    }

    @Test func freeTextSearchesCommitsOfTheSelectedSite() throws {
        let (query, unresolved) = try #require(deployments("analytics fix"))
        #expect(query.text == "analytics fix")
        #expect(unresolved == ["analytics", "fix"])
    }

    @Test func productionEnvironmentIsADeploymentFilterButEnvVarsIsTheCheck() {
        #expect(deployments("production environment deploys")?.0.target == .production)
        guard case .environment = planSiteSearch("env vars", projects: projects, selectedProjectID: selected).plan else {
            Issue.record("Expected the environment check"); return
        }
    }

    @Test func namingAnotherSiteOffersToSwitch() {
        guard case .otherSite(let site, let query) = planSiteSearch("failed deploys on example-store", projects: projects,
                                                                   selectedProjectID: selected).plan else {
            Issue.record("Expected an offer to switch sites"); return
        }
        #expect(site.id == DemoIDs.store)
        #expect(query.states == DeploymentQuery.failedStates)
    }

    @Test func selectedSiteIsRequiredForStateAndEnvironmentSearches() {
        for query in ["ready", "failed", "environment", "successful deployments"] {
            guard case .chooseSite = planSiteSearch(query, projects: projects, selectedProjectID: nil).plan else {
                Issue.record("Must not imply account-wide deployment coverage"); continue
            }
        }
    }

    @Test func exactProjectNameWinsOverAStateKeyword() {
        var project = projects.first!
        project.name = "ready"
        guard case .sites(let found) = planSiteSearch("ready", projects: [project], selectedProjectID: project.id).plan else {
            Issue.record("A project named ready should still be selectable"); return
        }
        #expect(found.first?.id == project.id)
    }

    @Test func partialQueriesAndUnknownQueriesStayDistinct() {
        guard case .sites(let found) = planSiteSearch("portfolio", projects: projects, selectedProjectID: nil).plan else {
            Issue.record("Partial site query should find its site"); return
        }
        #expect(!found.isEmpty)
        guard case .noMatch = planSiteSearch("zzznomatches", projects: projects, selectedProjectID: nil).plan else {
            Issue.record("Unknown query must not fabricate a result"); return
        }
    }
}

struct DeploymentQueryTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let now = Date(timeIntervalSince1970: 1_793_145_600) // 2026-10-28 00:00 UTC

    private func deploy(_ state: DeploymentState, target: DeploymentTarget?, ref: String = "main", message: String = "Fix analytics totals",
                        minutesAgo: Double = 10) -> VercelDeploymentSummary {
        VercelDeploymentSummary(id: UUID().uuidString, name: "site", state: state, target: target,
                                createdAt: (now.timeIntervalSince1970 - minutesAgo * 60) * 1000,
                                meta: GitMeta(githubCommitRef: ref, githubCommitSha: "3f2a91c0d4e5f60718293a4b5c6d7e8f90a1b2c3",
                                              githubCommitMessage: message))
    }

    @Test func apiParametersUseVercelFilterNames() {
        var query = DeploymentQuery(states: DeploymentQuery.failedStates, target: .production, branch: "main", window: .yesterday)
        let params = query.apiParameters(now: now, calendar: calendar)
        #expect(params["state"] == "BLOCKED,CANCELED,ERROR")
        #expect(params["target"] == "production")
        #expect(params["branch"] == "main")
        #expect(params["since"] == "1793059200000")
        #expect(params["until"] == "1793145600000")
        query.sha = "3f2a91c"
        #expect(query.apiParameters(now: now, calendar: calendar)["sha"] == nil, "Short SHAs are matched on the device")
        query.sha = "3f2a91c0d4e5f60718293a4b5c6d7e8f90a1b2c3"
        #expect(query.apiParameters(now: now, calendar: calendar)["sha"] == query.sha)
    }

    @Test func localMatchingAppliesEveryFilter() {
        let query = DeploymentQuery(states: [.ready], target: .preview, sha: "3F2A91C", window: .lastHours(1), text: "analytics fix")
        #expect(query.matches(deploy(.ready, target: nil), now: now, calendar: calendar), "Previews may have no target")
        #expect(query.matches(deploy(.ready, target: .preview), now: now, calendar: calendar))
        #expect(!query.matches(deploy(.ready, target: .production), now: now, calendar: calendar))
        #expect(!query.matches(deploy(.error, target: .preview), now: now, calendar: calendar))
        #expect(!query.matches(deploy(.ready, target: .preview, minutesAgo: 90), now: now, calendar: calendar))
        #expect(!query.matches(deploy(.ready, target: .preview, message: "Update copy"), now: now, calendar: calendar))
    }

    @Test func phraseReadsBackAsTheSameQuery() {
        let queries = [
            DeploymentQuery(states: [.ready]),
            DeploymentQuery(states: DeploymentQuery.failedStates, target: .preview, window: .yesterday),
            DeploymentQuery(states: [.ready], branch: "Feature/Login", limit: 1),
            DeploymentQuery(states: DeploymentQuery.inFlightStates.union([.ready]), target: .production, window: .lastDays(7)),
            DeploymentQuery(states: [.canceled], window: .lastHours(1), text: "fix analytics", limit: 5),
            DeploymentQuery(sha: "3f2a91c", window: .thisWeek),
            DeploymentQuery(),
        ]
        for query in queries {
            let plan = planSiteSearch(query.phrase, projects: buildDemoProjects(), selectedProjectID: DemoIDs.portfolio).plan
            #expect(plan == .deployments(query), "\(query.phrase)")
        }
    }

    @Test func titlesAndCaptionsDescribeWhatCameBack() {
        #expect(DeploymentQuery(states: DeploymentQuery.inFlightStates.union([.ready])).title == "Deployments that didn't fail")
        #expect(DeploymentQuery(states: [.ready], target: .production, limit: 1).title == "Latest ready production deployment")
        let ready = DeploymentQuery(states: [.ready])
        #expect(ready.coverage(count: 16) == "All 16 matches from Vercel.")
        #expect(ready.coverage(count: 20) == "Newest 20 matches from Vercel.")
        #expect(ready.coverage(count: 1, source: "demo data") == "The only match from demo data.")
        #expect(ready.coverage(count: 0) == nil)
        #expect(DeploymentQuery(text: "fix").coverage(count: 3)?.contains("newest 100") == true)
    }

    @Test func removingFiltersWidensTheQuery() {
        let query = DeploymentQuery(states: [.ready], target: .production, window: .today, limit: 1)
        #expect(query.filters.map(\.kind) == [.state, .target, .window, .limit])
        let widened = query.removing(.target).removing(.limit)
        #expect(widened.target == nil)
        #expect(widened.limit == DeploymentQuery.defaultLimit)
        #expect(widened.states == [.ready])
    }
}

struct SearchModelPolicyTests {
    private let projects = buildDemoProjects()

    @Test func modelFillsOnlyWhatTheRulesCouldNotPlace() throws {
        let failedRules = planSiteSearch("successful deploys since the outage", projects: projects, selectedProjectID: DemoIDs.portfolio)
        let draft = SearchModelDraft(intent: .deployments, outcomes: [.failed], environment: .production,
                                     timeframe: .lastHours, amount: 12)
        let plan = try #require(SearchModelPolicy.plan(draft, query: "successful deploys since the outage", rules: failedRules,
                                                       projects: projects, selectedProjectID: DemoIDs.portfolio))
        guard case .deployments(let query) = plan else { Issue.record("Expected deployments"); return }
        #expect(query.states == [.ready], "The rules' explicit outcome wins")
        #expect(query.target == .production)
        #expect(query.window == .lastHours(12))
        #expect(query.text == nil, "Leftover words are no longer a text filter once the model reads them")
    }

    @Test func inventedValuesAreDiscarded() throws {
        let text = "deploys after the redesign"
        let rules = planSiteSearch(text, projects: projects, selectedProjectID: DemoIDs.portfolio)
        let draft = SearchModelDraft(intent: .deployments, branch: "release/2.0", commitText: "redesign",
                                     siteName: "example-store")
        let plan = try #require(SearchModelPolicy.plan(draft, query: text, rules: rules, projects: projects,
                                                       selectedProjectID: DemoIDs.portfolio))
        guard case .deployments(let query) = plan else { Issue.record("A site not named in the request must not switch scope"); return }
        #expect(query.branch == nil)
        #expect(query.text == "redesign")
    }

    @Test func modelThatAddsNothingLeavesTheRulesInCharge() {
        let text = "successful deploys tuesday"
        let rules = planSiteSearch(text, projects: projects, selectedProjectID: DemoIDs.portfolio)
        let draft = SearchModelDraft(intent: .deployments, outcomes: [.ready], commitText: "successful")
        #expect(SearchModelPolicy.plan(draft, query: text, rules: rules, projects: projects, selectedProjectID: DemoIDs.portfolio) == nil)
        #expect(SearchModelPolicy.plan(.init(intent: .unclear), query: text, rules: rules, projects: projects,
                                       selectedProjectID: DemoIDs.portfolio) == nil)
    }

    @Test func promptRejectsSecretsAndBoundsInput() {
        #expect(SearchModelPolicy.prompt("deploys with vcp_abc123", siteNames: []) == nil)
        #expect(SearchModelPolicy.prompt(String(repeating: "a", count: 201), siteNames: []) == nil)
        let prompt = SearchModelPolicy.prompt("failed deploys", siteNames: Array(repeating: "alpha", count: 50))
        #expect(prompt?.components(separatedBy: "alpha").count == SearchModelPolicy.maximumSiteNames + 1)
    }
}
