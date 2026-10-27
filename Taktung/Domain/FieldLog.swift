import Foundation

enum FieldLogScope: String, CaseIterable { case site, all }

enum FieldLogFilter: String, CaseIterable {
    case all, important, notes, changes, issues

    var title: String {
        switch self {
        case .all: "All events"
        case .important: "Important"
        case .notes: "Notes"
        case .changes: "Changes"
        case .issues: "Issues"
        }
    }
}

struct FieldLogDay: Identifiable {
    var date: Date
    var entries: [ActivityItem]
    var id: Date { date }
}

extension ActivityItem {
    /// Present the early log's internal labels without rewriting stored evidence.
    var displayTitle: String {
        guard outcome == .success else { return title }
        switch (kind, title) {
        case (.connect, "connect"): return "Connected to Vercel"
        case (.refreshProjects, "refresh projects"): return "Projects refreshed"
        default: return title
        }
    }

    var displayDetail: String {
        guard outcome == .success else { return detail }
        if kind == .connect, detail == "connect:success" { return "Vercel connection verified." }
        if kind == .refreshProjects, detail == "refresh_projects:success" { return "Project list refreshed." }
        guard let first = detail.split(separator: " ").first, let count = Int(first), count >= 0 else { return detail }
        if kind == .refreshProjects,
           detail == "\(count) project(s)" || detail == "\(count) project(s) (list without N+1 deploy fan-out)" {
            return "\(count) \(count == 1 ? "project" : "projects") loaded."
        }
        if kind == .loadDeployments, detail == "\(count) deployment(s)" {
            return "\(count) \(count == 1 ? "deployment" : "deployments") loaded."
        }
        return detail
    }
}

func fieldLogEntries(_ entries: [ActivityItem], projectID: ProjectID?, scope: FieldLogScope,
                     filter: FieldLogFilter, search: String) -> [ActivityItem] {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return entries.filter { item in
        let matchesSite = scope == .all || projectID == nil || item.projectId == nil || item.projectId == projectID
        let isChange = [.redeploy, .promote, .rollback, .deploymentPoll, .planExecute].contains(item.kind)
        let isIssue = item.outcome == .failure || item.outcome == .canceled
        let matchesFilter: Bool
        switch filter {
        case .all: matchesFilter = true
        case .important: matchesFilter = isIssue || isChange || [.note, .deploymentCompare, .incidentSummary, .envDrift].contains(item.kind)
        case .notes: matchesFilter = item.kind == .note
        case .changes: matchesFilter = isChange
        case .issues: matchesFilter = isIssue
        }
        let matchesSearch = query.isEmpty || [item.displayTitle, item.displayDetail, item.projectName ?? "", item.projectId ?? "", item.deploymentId ?? ""]
            .contains { $0.localizedCaseInsensitiveContains(query) }
        return matchesSite && matchesFilter && matchesSearch
    }.sorted { lhs, rhs in
        lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt > rhs.createdAt
    }
}

func fieldLogDays(_ entries: [ActivityItem], calendar: Calendar = .current) -> [FieldLogDay] {
    let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.createdAt) }
    return grouped.keys.sorted(by: >).map { day in
        FieldLogDay(date: day, entries: grouped[day, default: []].sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt > $1.createdAt
        })
    }
}
