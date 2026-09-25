import Foundation

enum HealthLevel: String, Sendable {
    case healthy
    case degraded
    case critical
    case unknown
}

struct ProjectHealthCard: Sendable {
    var level: HealthLevel
    var score: Int
    var headline: String
    var bullets: [String]
    var suggestedNextStep: String?
    var attentionReason: AttentionReason
}

func isFailedState(_ state: DeploymentState) -> Bool {
    state == .blocked || state == .error || state == .canceled
}

func isSuccessState(_ state: DeploymentState) -> Bool {
    state == .ready
}

func isInFlightState(_ state: DeploymentState) -> Bool {
    state == .building || state == .initializing || state == .queued
}

func computeAttention(
    production: VercelDeploymentSummary?,
    latest: VercelDeploymentSummary?,
    lastSuccess: VercelDeploymentSummary?,
    latestFailed: VercelDeploymentSummary?
) -> (needsAttention: Bool, reason: AttentionReason) {
    if let prod = production, isFailedState(prod.state) {
        return (true, .latestProductionFailed)
    }
    if let prod = production, isInFlightState(prod.state) {
        return (true, .building)
    }
    if production == nil, latestFailed != nil {
        return (true, .latestProductionFailed)
    }
    if production == nil {
        return (true, .noProduction)
    }
    if let prod = production, isSuccessState(prod.state), let failed = latestFailed {
        let failedAfterProd = failed.createdAt > prod.createdAt
        let otherFailedProduction = failed.target == .production && failed.id != prod.id
        if failedAfterProd || otherFailedProduction {
            return (true, .recentFailure)
        }
    }
    _ = latest
    _ = lastSuccess
    return (false, .none)
}

func summarizeDeployments(_ deployments: [VercelDeploymentSummary]) -> (
    production: VercelDeploymentSummary?,
    latest: VercelDeploymentSummary?,
    lastSuccess: VercelDeploymentSummary?,
    latestFailed: VercelDeploymentSummary?
) {
    let sorted = deployments.sorted { $0.createdAt > $1.createdAt }
    let latest = sorted.first
    let production = sorted.first { $0.target == .production }
    let lastSuccess =
        sorted.first { isSuccessState($0.state) && $0.target == .production }
        ?? sorted.first { isSuccessState($0.state) }
    let latestFailed = sorted.first { isFailedState($0.state) }
    return (production, latest, lastSuccess, latestFailed)
}

func buildProjectHealthCard(_ project: VercelProject, now: Date = Date()) -> ProjectHealthCard {
    var bullets: [String] = []
    var level: HealthLevel = .healthy
    var score = 90
    var headline = "Production health: Healthy"
    var suggestedNextStep: String?

    if let prod = project.productionDeployment {
        var line = "Latest production: \(prod.state.rawValue)"
        if let ref = prod.meta.githubCommitRef { line += " · \(ref)" }
        bullets.append(line)
    } else {
        bullets.append("No production deployment found")
    }

    if let last = project.lastSuccessfulDeployment {
        bullets.append("Last successful: \(shortSha(last)) · \(formatAgo(last.createdAt, now: now))")
    }
    if let failed = project.latestFailedDeployment {
        let msg = failed.meta.githubCommitMessage.map { String($0.prefix(80)) } ?? failed.state.rawValue
        bullets.append("Latest failed: \(shortSha(failed)) · \(msg)")
    }

    switch project.attentionReason {
    case .latestProductionFailed:
        level = .critical
        score = 25
        headline = "Production health: Critical"
        suggestedNextStep =
            "Open the failed deployment, review build logs, then compare with last successful."
    case .building:
        level = .degraded
        score = 55
        headline = "Production health: Deploying"
        suggestedNextStep = "Wait for the build to finish, then refresh."
    case .noProduction:
        level = .unknown
        score = 40
        headline = "Production health: Unknown"
        suggestedNextStep = "Confirm a production deployment exists for this project."
    case .recentFailure:
        level = .degraded
        score = 62
        headline = "Production is READY · recent failure in history"
        suggestedNextStep =
            "Open the failed deployment, run Diagnose, then decide whether a rollback is needed."
    case .staleSuccess:
        level = .degraded
        score = 60
        headline = "Production health: Degraded"
    case .none:
        if project.needsAttention {
            level = .degraded
            score = 60
            headline = "Production health: Degraded"
        }
    }

    if let framework = project.framework { bullets.append("Framework: \(framework)") }
    if let domain = project.primaryDomain { bullets.append("Primary domain: \(domain)") }

    return ProjectHealthCard(
        level: level,
        score: score,
        headline: headline,
        bullets: bullets,
        suggestedNextStep: suggestedNextStep,
        attentionReason: project.attentionReason
    )
}

func shortSha(_ d: VercelDeploymentSummary) -> String {
    if let sha = d.meta.githubCommitSha, sha.count >= 7 {
        return String(sha.prefix(7))
    }
    return String(d.id.prefix(8))
}

func formatAgo(_ ms: TimeInterval, now: Date = Date()) -> String {
    let delta = now.timeIntervalSince1970 * 1000 - ms
    if delta < 60_000 { return "just now" }
    if delta < 3_600_000 { return "\(Int(delta / 60_000))m ago" }
    if delta < 86_400_000 { return "\(Int(delta / 3_600_000))h ago" }
    return "\(Int(delta / 86_400_000))d ago"
}
