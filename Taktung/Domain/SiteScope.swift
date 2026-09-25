import Foundation

func siteTitle(_ project: VercelProject) -> String {
    let host = hostOf(project.primaryDomain)
    return host ?? project.name
}

func siteSubtitle(_ project: VercelProject) -> String {
    let host = hostOf(project.primaryDomain)
    if let host, host != project.name { return project.name }
    return [project.framework, project.productionDeployment?.state.rawValue]
        .compactMap { $0 }
        .joined(separator: " · ")
}

func siteRepoLabel(_ project: VercelProject) -> String? {
    let org = project.link?.org?.trimmingCharacters(in: .whitespacesAndNewlines)
    let repo = project.link?.repo?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let org, !org.isEmpty, let repo, !repo.isEmpty { return "\(org)/\(repo)" }
    if let repo, !repo.isEmpty { return repo }
    return nil
}

func siteHostLabel(_ project: VercelProject) -> String? {
    hostOf(project.primaryDomain)
}

func siteMetaLine(_ project: VercelProject) -> String? {
    let title = siteTitle(project)
    let parts = [siteHostLabel(project), siteRepoLabel(project)]
        .compactMap { $0 }
        .filter { $0 != title }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}

func siteStampProd(_ project: VercelProject) -> String {
    let deploy = project.productionDeployment ?? project.latestDeployment
    if let ref = deploy?.meta.githubCommitRef?.trimmingCharacters(in: .whitespacesAndNewlines),
       !ref.isEmpty
    {
        return ref
    }
    if let target = deploy?.target { return target.rawValue }
    return "NONE"
}

func siteStampGit(_ project: VercelProject) -> String {
    let deploy = project.productionDeployment ?? project.latestDeployment
    if let sha = deploy?.meta.githubCommitSha, sha.count >= 7 {
        return String(sha.prefix(7))
    }
    return "NONE"
}

func formatCompactAge(_ createdAt: TimeInterval, now: Date = Date()) -> String {
    let delta = max(0, now.timeIntervalSince1970 * 1000 - createdAt)
    if delta < 60_000 { return "now" }
    if delta < 3_600_000 { return "\(Int(delta / 60_000))m" }
    if delta < 86_400_000 { return "\(Int(delta / 3_600_000))h" }
    return "\(Int(delta / 86_400_000))d"
}

func siteStampAge(_ project: VercelProject, now: Date = Date()) -> (label: String, fill: Double) {
    guard let deploy = project.productionDeployment ?? project.latestDeployment else {
        return ("NONE", 0)
    }
    let minutes = max(0, now.timeIntervalSince1970 * 1000 - deploy.createdAt) / 60_000
    return (formatCompactAge(deploy.createdAt, now: now), min(1, minutes / (24 * 60)))
}

struct ClearWord: Sendable {
    var label: String
    var tone: ConsoleStateTone
}

func siteClearWord(_ project: VercelProject) -> ClearWord {
    if !project.needsAttention { return ClearWord(label: "ALL CLEAR", tone: .ready) }
    switch project.attentionReason {
    case .latestProductionFailed: return ClearWord(label: "CRITICAL", tone: .error)
    case .building: return ClearWord(label: "BUILDING", tone: .building)
    case .noProduction: return ClearWord(label: "NO PROD", tone: .neutral)
    default: return ClearWord(label: "ATTENTION", tone: .building)
    }
}

func rankSites(_ projects: [VercelProject], query: String = "") -> [VercelProject] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let filtered: [VercelProject]
    if q.isEmpty {
        filtered = projects
    } else {
        filtered = projects.filter { p in
            [
                p.name,
                p.primaryDomain,
                siteTitle(p),
                siteRepoLabel(p),
                p.framework,
            ]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            .contains(q)
        }
    }
    return filtered.sorted { a, b in
        if a.needsAttention != b.needsAttention { return a.needsAttention && !b.needsAttention }
        return siteTitle(a).localizedCaseInsensitiveCompare(siteTitle(b)) == .orderedAscending
    }
}

private func hostOf(_ value: String?) -> String? {
    guard var value, !value.isEmpty else { return nil }
    if let range = value.range(of: "://") {
        value = String(value[range.upperBound...])
    }
    if let slash = value.firstIndex(of: "/") {
        value = String(value[..<slash])
    }
    return value.isEmpty ? nil : value
}
