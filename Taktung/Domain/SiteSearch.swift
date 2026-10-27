import Foundation

/// Results refer only to projects and deployments already loaded for this session.
/// Site matches are resolved before state words, so a site named "ready" stays a site.
enum SiteSearchResult {
    case sites([VercelProject])
    case deployments(title: String, items: [VercelDeploymentSummary])
    case environment
    case chooseSite
    case noMatch
}

func searchLoadedSite(_ query: String, projects: [VercelProject], deployments: [VercelDeploymentSummary], selectedProjectID: ProjectID?) -> SiteSearchResult {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !q.isEmpty else { return .noMatch }
    let host = URLComponents(string: q.contains("://") ? q : "https://\(q)")?.host
    let exact = projects.filter { project in
        let names = [project.name.lowercased(), siteTitle(project).lowercased(), siteRepoLabel(project)?.lowercased()]
        return names.contains(q) || (host == q || q.contains("://")) && siteTitle(project).lowercased() == host
    }
    if !exact.isEmpty { return .sites(rankSites(exact)) }

    let words = Set(q.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
    let failed = !words.isDisjoint(with: ["failed", "failing", "failure", "fail", "error", "errors", "canceled", "cancelled"])
    let ready = words.contains("ready")
    let environment = !words.isDisjoint(with: ["env", "environment", "variables"])
    if failed || ready || environment {
        guard selectedProjectID != nil else { return .chooseSite }
        if environment { return .environment }
        return .deployments(title: failed ? "Failed deployments" : "Ready deployments",
                            items: deployments.filter { failed ? isFailedState($0.state) : $0.state == .ready })
    }
    let matches = rankSites(projects, query: q)
    return matches.isEmpty ? .noMatch : .sites(matches)
}
