import Foundation
import Testing
@testable import Taktung

struct FieldLogQueryTests {
    private let projects = buildDemoProjects()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func read(_ text: String) -> FieldLogInterpretation {
        FieldLogRules.parse(text, projects: projects)
    }

    private func entry(_ id: String, kind: ActivityKind = .note, title: String = "Note", outcome: ActivityOutcome = .info,
                       project: ProjectID? = DemoIDs.portfolio, hoursAgo: Double = 1, detail: String = "Checked the hero") -> ActivityItem {
        ActivityItem(id: id, kind: kind, title: title, detail: detail, outcome: outcome,
                     createdAt: now.addingTimeInterval(-hoursAgo * 3_600), projectId: project,
                     deploymentId: nil, projectName: project == nil ? nil : "Portfolio")
    }

    @Test func plainRequestsBecomeCategoriesOutcomesAndTime() {
        let notes = read("my notes about the cache bug")
        #expect(notes.query.categories == [.notes])
        #expect(notes.query.text == "cache bug")
        #expect(notes.unresolved == ["cache", "bug"])

        let failed = read("failed checks this week")
        #expect(failed.query.categories == [.checks])
        #expect(failed.query.outcomes == [.failure])
        #expect(failed.query.window == .thisWeek)
        #expect(failed.query.text == nil)
        #expect(!failed.needsModel)

        let comparisons = read("comparisons from the last 3 days")
        #expect(comparisons.query.categories == [.comparisons])
        #expect(comparisons.query.window == .lastDays(3))

        let rollbacks = read("rollbacks yesterday")
        #expect(rollbacks.query.categories == [.actions])
        #expect(rollbacks.query.window == .yesterday)
    }

    @Test func fieldLogPhraseAndNegationReadNaturally() {
        let everything = read("search the field log for hero")
        #expect(everything.query.categories.isEmpty)
        #expect(everything.query.text == "hero")
        let clean = read("checks that didn't fail")
        #expect(clean.query.categories == [.checks])
        #expect(clean.query.outcomes == [.success, .info])
        #expect(clean.query.outcomeLabel == "No problems")
        #expect(read("problems").query.outcomes == [.failure, .canceled])
    }

    @Test func namedSitesAndAllSitesOverrideTheScreenScope() {
        let store = read("notes on example-store")
        #expect(store.query.site == DemoIDs.store)
        #expect(store.query.siteName == "example-store.app")
        #expect(read("failures across all sites").query.allSites)
        let entries = [entry("portfolio"), entry("store", project: DemoIDs.store)]
        let found = fieldLogEntries(entries, projectID: DemoIDs.portfolio, scope: .site, filter: .all, query: store.query, now: now)
        #expect(found.map(\.id) == ["store"])
    }

    @Test func matchingAppliesEveryFilterAndKeepsDiagnoseOutOfNotes() {
        let entries = [
            entry("note", detail: "Cache bug on the hero"),
            entry("diagnose", title: "Diagnose", detail: "Cache looks stable"),
            entry("compare", kind: .deploymentCompare, title: "Compared", outcome: .success, detail: "Hero changed"),
            entry("poll", kind: .deploymentPoll, title: "Deploy poll finished", outcome: .failure, detail: "ERROR"),
            entry("old", hoursAgo: 24 * 30, detail: "Cache bug from last month"),
            entry("routine", kind: .loadDeployments, title: "Loaded deployments", outcome: .success, detail: "Cache 3"),
        ]
        func ids(_ text: String) -> [String] {
            fieldLogEntries(entries, projectID: DemoIDs.portfolio, scope: .site, filter: .all, query: read(text).query, now: now).map(\.id)
        }
        #expect(ids("notes about cache") == ["note", "old"])
        #expect(ids("notes about cache in the last 7 days") == ["note"])
        #expect(ids("checks") == ["diagnose"])
        #expect(ids("failed deploys") == ["poll"])
        #expect(ids("comparisons") == ["compare"])
        // Routine records have no category; they are found only by text.
        #expect(ids("cache 3").contains("routine"))
    }

    @Test func chipsDescribeAndRemoveEachFilter() {
        var query = read("failed checks on example-store this week \"timeout\"").query
        #expect(query.filters.map(\.label) == ["Checks", "Failed", "example-store.app", "This week", "“timeout”"])
        query = query.removing(.site).removing(.category(.checks))
        #expect(query.filters.map(\.label) == ["Failed", "This week", "“timeout”"])
        #expect(!query.removing(.outcome).removing(.window).removing(.text).hasFilters)
    }

    @Test func modelFillsOnlyWhatTheRulesLeftOpenAndCopiesTextLiterally() {
        let request = "what did I jot down while fixing checkout"
        let rules = read(request)
        #expect(rules.query.text?.contains("fixing") == true)
        let draft = FieldLogModelDraft(categories: [.notes], text: "checkout")
        let reading = FieldLogModelPolicy.interpretation(draft, query: request, rules: rules, projects: projects)
        #expect(reading?.interpreter == .appleIntelligence)
        #expect(reading?.query.categories == [.notes])
        #expect(reading?.query.text == "checkout")

        // Invented text and sites are discarded; with nothing else added, the rules stand.
        let invented = FieldLogModelDraft(siteName: "example-docs", text: "payment outage")
        #expect(FieldLogModelPolicy.interpretation(invented, query: request, rules: rules, projects: projects) == nil)

        // Rule-decided outcomes win over the model.
        let failed = read("failed things while fixing checkout")
        let contrary = FieldLogModelDraft(outcomes: [.succeeded], text: "checkout")
        #expect(FieldLogModelPolicy.interpretation(contrary, query: "failed things while fixing checkout", rules: failed,
                                                   projects: projects)?.query.outcomes == [.failure])
    }

    @Test func promptHoldsTheRequestAndSiteNamesOnly() {
        let prompt = FieldLogModelPolicy.prompt("notes about checkout", siteNames: ["example-portfolio.app"])
        #expect(prompt == "Loaded sites: example-portfolio.app\nRequest: notes about checkout")
        #expect(FieldLogModelPolicy.prompt("token vcp_secret_value_123456", siteNames: []) == nil)
        #expect(FieldLogModelPolicy.prompt(String(repeating: "a", count: 201), siteNames: []) == nil)
    }
}
