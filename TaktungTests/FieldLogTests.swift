import Foundation
import Testing
@testable import Taktung

struct FieldLogTests {
    @Test func legacyRoutineEventsReadPlainlyWithoutChangingRecords() {
        var item = entry("legacy", kind: .refreshProjects, outcome: .success,
                         detail: "4 project(s) (list without N+1 deploy fan-out)")
        item.title = "refresh projects"
        #expect(item.displayTitle == "Projects refreshed")
        #expect(item.displayDetail == "4 projects loaded.")
        #expect(item.title == "refresh projects")
        #expect(item.detail.contains("N+1"))
        #expect(historyExport([item]).contains("4 projects loaded."))
        #expect(!historyExport([item]).contains("fan-out"))
        #expect(fieldLogEntries([item], projectID: nil, scope: .all, filter: .all,
                               search: "4 projects loaded").map(\.id) == ["legacy"])
        item.kind = .loadDeployments
        item.detail = "1 deployment(s)"
        #expect(item.displayDetail == "1 deployment loaded.")
    }

    @Test func legacyPresentationLeavesNotesFailuresAndUnrecognizedDetailsUntouched() {
        var item = entry("untouched", detail: "4 project(s) (list without N+1 deploy fan-out)")
        #expect(item.displayDetail == item.detail)
        item.kind = .refreshProjects
        item.outcome = .failure
        #expect(item.displayDetail == item.detail)
        item.outcome = .success
        item.detail = "4 project(s) failed to load"
        #expect(item.displayDetail == item.detail)
        item.kind = .connect
        item.title = "connect"
        item.detail = "connect:success"
        #expect(item.displayTitle == "Connected to Vercel")
        #expect(item.displayDetail == "Vercel connection verified.")
    }

    private func entry(_ id: String, kind: ActivityKind = .note, outcome: ActivityOutcome = .info,
                       project: String? = "site-a", time: TimeInterval = 1, detail: String = "Homepage reviewed") -> ActivityItem {
        ActivityItem(id: id, kind: kind, title: "Review", detail: detail, outcome: outcome,
                     createdAt: Date(timeIntervalSince1970: time), projectId: project,
                     deploymentId: "deployment-123", projectName: project == nil ? nil : "Portfolio")
    }

    @Test func siteScopeIncludesAccountRecordsButExcludesOtherSites() {
        let entries = [entry("site"), entry("other", project: "site-b"), entry("account", project: nil)]
        #expect(Set(fieldLogEntries(entries, projectID: "site-a", scope: .site, filter: .all, search: "").map(\.id)) == ["site", "account"])
        #expect(fieldLogEntries(entries, projectID: "site-a", scope: .all, filter: .all, search: "").count == 3)
        #expect(fieldLogEntries(entries, projectID: nil, scope: .site, filter: .all, search: "").count == 3)
    }

    @Test func searchScopeAndEventFilterCombine() {
        let entries = [entry("note", detail: "Check HERO spacing"),
                       entry("other", project: "site-b", detail: "Check hero"),
                       entry("check", kind: .loadDeployments, detail: "Check hero")]
        let result = fieldLogEntries(entries, projectID: "site-a", scope: .site, filter: .notes, search: "  hero \n")
        #expect(result.map(\.id) == ["note"])
        #expect(fieldLogEntries(entries, projectID: "site-a", scope: .site, filter: .notes, search: "absent").isEmpty)
        #expect(fieldLogEntries(entries, projectID: "site-a", scope: .site, filter: .notes, search: "DEPLOYMENT-123").map(\.id) == ["note"])
    }

    @Test func issuesAndImportantDoNotHideCanceledOrFailedChecks() {
        let entries = [entry("routine", kind: .loadDeployments, outcome: .success),
                       entry("canceled", kind: .redeploy, outcome: .canceled),
                       entry("failed", kind: .loadLogs, outcome: .failure),
                       entry("comparison", kind: .deploymentCompare, outcome: .success)]
        #expect(Set(fieldLogEntries(entries, projectID: nil, scope: .all, filter: .issues, search: "").map(\.id)) == ["canceled", "failed"])
        #expect(Set(fieldLogEntries(entries, projectID: nil, scope: .all, filter: .important, search: "").map(\.id)) == ["canceled", "failed", "comparison"])
        #expect(fieldLogEntries(entries, projectID: nil, scope: .all, filter: .changes, search: "").map(\.id) == ["canceled"])
    }

    @Test func sortingIsStableWhenTimestampsMatch() {
        let entries = [entry("z"), entry("b", time: 2), entry("a")]
        #expect(fieldLogEntries(entries, projectID: nil, scope: .all, filter: .all, search: "").map(\.id) == ["b", "a", "z"])
        #expect(fieldLogDays(entries).flatMap(\.entries).map(\.id) == ["b", "a", "z"])
    }

    @Test func dayGroupsUseLocalCalendarAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let formatter = ISO8601DateFormatter()
        let beforeMidnight = try #require(formatter.date(from: "2026-11-01T06:59:00Z"))
        let afterMidnight = try #require(formatter.date(from: "2026-11-01T07:01:00Z"))
        let repeatedHour = try #require(formatter.date(from: "2026-11-01T09:30:00Z"))
        let entries = [entry("before", time: beforeMidnight.timeIntervalSince1970),
                       entry("after", time: afterMidnight.timeIntervalSince1970),
                       entry("repeated", time: repeatedHour.timeIntervalSince1970)]
        let groups = fieldLogDays(entries, calendar: calendar)
        #expect(groups.count == 2)
        #expect(groups[0].entries.map(\.id) == ["repeated", "after"])
        #expect(groups[1].entries.map(\.id) == ["before"])
        #expect(calendar.component(.day, from: groups[0].date) == 1)
        #expect(calendar.component(.day, from: groups[1].date) == 31)
    }
}
