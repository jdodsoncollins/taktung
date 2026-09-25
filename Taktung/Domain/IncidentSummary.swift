import Foundation

struct IncidentSummary: Sendable {
    var headline: String
    var likelyCause: String?
    var evidence: [String]
    var comparedWith: String?
    var suggestedAction: String
    var confidence: Confidence
    var commitSubject: String?
    var commitSha: String?

    enum Confidence: String, Sendable {
        case low
        case medium
        case high
    }
}

func firstCommitLine(_ message: String?, max: Int = 88) -> String? {
    guard let message else { return nil }
    let line = message.split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .first { !$0.isEmpty } ?? ""
    if line.isEmpty { return nil }
    if line.count > max { return String(line.prefix(max)) + "…" }
    return line
}

private let envHint = try! NSRegularExpression(
    pattern: #"\b(env|environment variable|process\.env|missing|undefined|SECRET|API_KEY|TOKEN)\b"#,
    options: .caseInsensitive
)
private let moduleHint = try! NSRegularExpression(
    pattern: #"\b(Cannot find module|Module not found|ERR_MODULE_NOT_FOUND)\b"#,
    options: .caseInsensitive
)
private let typeHint = try! NSRegularExpression(
    pattern: #"\b(Type error|TS\d{4}|Failed to compile)\b"#,
    options: .caseInsensitive
)
private let oomHint = try! NSRegularExpression(
    pattern: #"\b(JavaScript heap out of memory|ENOMEM|killed)\b"#,
    options: .caseInsensitive
)

private func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
    regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
}

/// Local, deterministic incident summary from deployment + log tails. No LLM required.
func summarizeFailedDeployment(
    failed: VercelDeploymentSummary,
    lastSuccess: VercelDeploymentSummary?,
    logLines: [BuildLogLine],
    missingProductionEnvKeys: [String] = []
) -> IncidentSummary {
    let commitSubject = firstCommitLine(failed.meta.githubCommitMessage)
    let commitSha = failed.meta.githubCommitSha.map { String($0.prefix(12)) }

    if !isFailedState(failed.state) {
        return IncidentSummary(
            headline: "\(failed.name) is \(failed.state.rawValue)",
            likelyCause: nil,
            evidence: [],
            comparedWith: nil,
            suggestedAction:
                "This deployment did not fail. Open it from Deployments, or pick a failed row.",
            confidence: .low,
            commitSubject: commitSubject,
            commitSha: commitSha
        )
    }

    var evidence: [String] = [
        "Failed deployment \(failed.id) state=\(failed.state.rawValue) target=\(failed.target?.rawValue ?? "unknown")"
    ]
    let logText = logLines.map(\.text).joined(separator: "\n")
    var likelyCause: String?
    var confidence: IncidentSummary.Confidence = .low
    var suggestedAction =
        "Open full build logs, fix the root error, and redeploy after review."

    if !missingProductionEnvKeys.isEmpty {
        let shown = missingProductionEnvKeys.prefix(5).joined(separator: ", ")
        let extra = missingProductionEnvKeys.count > 5 ? "…" : ""
        likelyCause = "Missing production environment variable(s): \(shown)\(extra)"
        confidence = .high
        evidence.append(
            "Env presence check (names only): \(missingProductionEnvKeys.count) key(s) in Preview but not Production"
        )
        suggestedAction =
            "Add the missing variable name(s) to Production in Vercel, then redeploy. Values are never shown in Taktung."
    } else if matches(oomHint, logText) {
        likelyCause = "Build ran out of memory"
        confidence = .high
        evidence.append("Log signature: out-of-memory / killed process")
        suggestedAction =
            "Reduce build memory pressure or increase function/build resources, then redeploy."
    } else if matches(moduleHint, logText) {
        likelyCause = "Missing dependency or import path"
        confidence = .high
        evidence.append("Log signature: module not found")
        suggestedAction = "Fix the import or install the dependency, push, and redeploy."
    } else if matches(typeHint, logText) {
        likelyCause = "TypeScript / compile error"
        confidence = .high
        evidence.append("Log signature: type/compile failure")
        suggestedAction = "Fix the compile error locally, then redeploy."
    } else if matches(envHint, logText) {
        likelyCause = "Possible environment variable issue (from log keywords)"
        confidence = .medium
        evidence.append("Log keywords suggest env/config problem")
        suggestedAction =
            "Run env drift check (names only) and compare with last successful deployment config."
    } else if logLines.isEmpty {
        likelyCause = nil
        confidence = .low
        evidence.append("No build log lines available yet")
        suggestedAction =
            "Refresh build logs. If still empty, open the deployment in Vercel dashboard."
    } else {
        if let tail = logLines.suffix(5).map(\.text).map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .last(where: { !$0.isEmpty })
        {
            evidence.append("Log tail: \(String(tail.prefix(160)))")
        }
        likelyCause = "Build failed — see log evidence"
        confidence = .low
    }

    var comparedWith: String?
    if let lastSuccess, isSuccessState(lastSuccess.state) {
        comparedWith = "\(lastSuccess.id) (\(shortCommitSha(lastSuccess.meta.githubCommitSha) ?? "ready"))"
        if let a = lastSuccess.meta.githubCommitSha, let b = failed.meta.githubCommitSha, a != b {
            evidence.append(
                "Commit changed since last success: \(String(a.prefix(7))) → \(String(b.prefix(7)))"
            )
        }
    }

    return IncidentSummary(
        headline: "Deployment failed: \(failed.name)",
        likelyCause: likelyCause,
        evidence: evidence,
        comparedWith: comparedWith,
        suggestedAction: suggestedAction,
        confidence: confidence,
        commitSubject: commitSubject,
        commitSha: commitSha
    )
}

func formatIncidentSummaryText(_ s: IncidentSummary) -> String {
    var lines = [
        s.headline,
        "",
        "Likely cause: \(s.likelyCause ?? "Unknown (low signal)")",
        "Confidence: \(s.confidence.rawValue)",
        "",
        "Evidence:",
    ]
    lines.append(contentsOf: s.evidence.map { "- \($0)" })
    if let compared = s.comparedWith {
        lines.append(contentsOf: ["", "Compared with last successful: \(compared)"])
    }
    lines.append(contentsOf: ["", "Suggested action: \(s.suggestedAction)"])
    return lines.joined(separator: "\n")
}
