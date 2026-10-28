import Foundation
import Testing
@testable import Taktung

struct FieldLogDigestTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ id: String, kind: ActivityKind = .note, title: String = "Note", outcome: ActivityOutcome = .info,
                       project: ProjectID? = "site-a", daysAgo: Double = 1, detail: String = "Checked the hero") -> ActivityItem {
        ActivityItem(id: id, kind: kind, title: title, detail: detail, outcome: outcome,
                     createdAt: now.addingTimeInterval(-daysAgo * 86_400), projectId: project,
                     deploymentId: nil, projectName: project == nil ? nil : "Portfolio")
    }

    private var week: [ActivityItem] {
        [
            entry("note", detail: "Checkout button overlaps on small phones"),
            entry("diagnose", title: "Diagnose", daysAgo: 2, detail: "Brief for portfolio"),
            entry("compare", kind: .deploymentCompare, title: "Compared deployments", outcome: .success, daysAgo: 3, detail: "Hero changed"),
            entry("poll", kind: .deploymentPoll, title: "Deploy poll finished", outcome: .failure, daysAgo: 4, detail: "ERROR after build"),
            entry("routine", kind: .loadDeployments, title: "Loaded deployments", outcome: .success, detail: "19 deployment(s)"),
            entry("old", daysAgo: 9, detail: "Last week's note"),
            entry("other", project: "site-b", detail: "Other site note"),
        ]
    }

    @Test func digestCountsTheLastSevenDaysForOneSiteWithoutRoutineLoads() {
        let digest = FieldLogDigestPolicy.digest(entries: week, projectID: "site-a", scopeLabel: "portfolio.app", now: now)
        #expect(digest.entries.map(\.id) == ["note", "diagnose", "compare", "poll"])
        #expect(digest.counts == .init(total: 4, notes: 1, checks: 1, comparisons: 1, actions: 1, failed: 1, canceled: 0))
        #expect(digest.facts == "Last 7 days: 1 note, 1 check, 1 comparison and 1 deploy action. 1 failed.")

        let all = FieldLogDigestPolicy.digest(entries: week, projectID: nil, scopeLabel: "All sites", now: now)
        #expect(all.entries.map(\.id).contains("other"))
        #expect(!all.entries.map(\.id).contains("old"))

        let empty = FieldLogDigestPolicy.digest(entries: [], projectID: nil, scopeLabel: "All sites", now: now)
        #expect(empty.facts == "No notes, checks, comparisons or deploy actions in the last 7 days.")
        #expect(FieldLogDigestPolicy.prompt(empty, includeSite: true) == nil)
    }

    @Test func promptIsRedactedBoundedAndListsEntriesNewestFirst() throws {
        var entries = week
        entries.append(entry("secret", daysAgo: 0.5, detail: "Rotated API_KEY=abc123secretvalue after the outage"))
        let digest = FieldLogDigestPolicy.digest(entries: entries, projectID: "site-a", scopeLabel: "portfolio.app", now: now)
        let prompt = try #require(FieldLogDigestPolicy.prompt(digest, includeSite: false))
        #expect(prompt.hasPrefix("Counts: Last 7 days:"))
        #expect(!prompt.contains("abc123secretvalue"))
        #expect(prompt.contains("Deploy poll finished — ERROR after build"))
        #expect(prompt.range(of: "Rotated")!.lowerBound < prompt.range(of: "Checkout button")!.lowerBound)
        #expect(!prompt.contains("Portfolio"))

        let flood = (0..<200).map { entry("n\($0)", daysAgo: Double($0) / 100, detail: String(repeating: "word ", count: 80)) }
        let large = FieldLogDigestPolicy.digest(entries: flood, projectID: "site-a", scopeLabel: "portfolio.app", now: now)
        #expect(large.entries.count == FieldLogDigestPolicy.maximumEntries)
        let bounded = try #require(FieldLogDigestPolicy.prompt(large, includeSite: false))
        #expect(bounded.utf8.count <= FieldLogDigestPolicy.maximumBytes)
    }

    @Test func summariesMustKeepStatedNumbersAndRecordedActions() throws {
        let digest = FieldLogDigestPolicy.digest(entries: week, projectID: "site-a", scopeLabel: "portfolio.app", now: now)
        let prompt = try #require(FieldLogDigestPolicy.prompt(digest, includeSite: false))
        let good = "One deploy poll failed after the build. You noted the checkout button overlaps on small phones, and a comparison showed the hero changed."
        #expect(FieldLogDigestPolicy.accept(good, prompt: prompt) == good)
        #expect(FieldLogDigestPolicy.accept("There were 97 failures this week.", prompt: prompt) == nil)
        #expect(FieldLogDigestPolicy.accept("You should roll back the latest deploy.", prompt: prompt) == nil)
        #expect(FieldLogDigestPolicy.accept("The 'payments' page broke.", prompt: prompt) == nil)
        #expect(FieldLogDigestPolicy.accept("One. Two. Three. Four.", prompt: prompt) == nil)
        #expect(FieldLogDigestPolicy.accept("A deploy failed\nand more.", prompt: prompt) == nil)

        // A recorded rollback may be described.
        let rolled = week + [entry("rollback", kind: .rollback, title: "Rollback production", daysAgo: 1, detail: "Accepted dpl_1. Polling for READY.")]
        let withRollback = try #require(FieldLogDigestPolicy.prompt(
            FieldLogDigestPolicy.digest(entries: rolled, projectID: "site-a", scopeLabel: "portfolio.app", now: now), includeSite: false))
        #expect(FieldLogDigestPolicy.accept("Production was rolled back after a failed deploy poll.", prompt: withRollback) == nil)
        #expect(FieldLogDigestPolicy.accept("A rollback of production was accepted after a failed deploy poll.", prompt: withRollback) != nil)
    }
}
