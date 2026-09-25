import Foundation

enum DeploymentListFilter: String, Sendable, CaseIterable, Identifiable {
    case all
    case failed
    case building
    case production

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .failed: "Failed"
        case .building: "Building"
        case .production: "Production"
        }
    }
}

func filterDeployments(
    _ deployments: [VercelDeploymentSummary],
    filter: DeploymentListFilter
) -> [VercelDeploymentSummary] {
    switch filter {
    case .failed: deployments.filter { isFailedState($0.state) }
    case .building: deployments.filter { isInFlightState($0.state) }
    case .production: deployments.filter { $0.target == .production }
    case .all: deployments
    }
}

func deploymentTitle(_ d: VercelDeploymentSummary) -> String {
    if let message = commitSubject(d.meta.githubCommitMessage) {
        return String(message.prefix(72))
    }
    return shortCommitSha(d.meta.githubCommitSha) ?? String(d.id.prefix(12))
}

func shortCommitSha(_ sha: String?) -> String? {
    guard let sha, sha.count >= 7 else { return nil }
    return String(sha.prefix(7))
}

func commitSubject(_ message: String?) -> String? {
    guard let message else { return nil }
    let line = message.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        .first?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return line.isEmpty ? nil : line
}

func deploymentListMetaLine(_ d: VercelDeploymentSummary, now: Date = Date()) -> String {
    [
        d.target?.rawValue ?? "no target",
        d.meta.githubCommitRef,
        shortCommitSha(d.meta.githubCommitSha),
        formatRelativeTime(d.createdAt, now: now),
    ]
    .compactMap { $0 }
    .filter { !$0.isEmpty }
    .joined(separator: " · ")
}

func deploymentRefLine(_ d: VercelDeploymentSummary) -> String {
    let build: String? = d.buildDurationMs.map { "\(Int(($0 / 1000).rounded()))s" }
    let parts = [d.meta.githubCommitRef, shortCommitSha(d.meta.githubCommitSha), build]
        .compactMap { $0 }
    return parts.isEmpty ? "unknown branch" : parts.joined(separator: " · ")
}

func deploymentProvenanceLine(_ d: VercelDeploymentSummary) -> String? {
    let login = d.meta.githubCommitAuthorLogin?.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
    let named = d.meta.githubCommitAuthorName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let creator = d.creatorUsername?.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))
    let actor: String? = {
        if let login, !login.isEmpty { return "@\(login)" }
        if let named, !named.isEmpty { return named }
        if let creator, !creator.isEmpty { return "@\(creator)" }
        return nil
    }()
    let parts = [d.source, actor, d.region].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
}

func formatRelativeTime(_ ms: TimeInterval, now: Date = Date()) -> String {
    let delta = now.timeIntervalSince1970 * 1000 - ms
    if delta < 60_000 { return "just now" }
    if delta < 3_600_000 { return "\(Int(delta / 60_000))m ago" }
    if delta < 86_400_000 { return "\(Int(delta / 3_600_000))h ago" }
    if delta < 7 * 86_400_000 { return "\(Int(delta / 86_400_000))d ago" }
    let date = Date(timeIntervalSince1970: ms / 1000)
    return date.formatted(date: .abbreviated, time: .omitted)
}

func countDeploymentsByFilter(_ deployments: [VercelDeploymentSummary]) -> [DeploymentListFilter: Int] {
    [
        .all: deployments.count,
        .failed: deployments.filter { isFailedState($0.state) }.count,
        .building: deployments.filter { isInFlightState($0.state) }.count,
        .production: deployments.filter { $0.target == .production }.count,
    ]
}
