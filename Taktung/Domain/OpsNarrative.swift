import Foundation

struct BoundedOpsContext: Sendable {
    var projectName: String?
    var productionState: String?
    var needsAttention: Bool
    var attentionReason: String?
    var incidentHeadline: String?
    var incidentCause: String?
    var incidentConfidence: String?
    var envDriftCritical: Int
    var envDriftSummary: String?
    var compareRisk: String?
    var compareSummary: String?
    var runtimeErrorCount: Int?
    var runtimeSummary: String?
    var domainCritical: Int
    var domainSummary: String?
    var polling: Bool
    var lastMutatorNote: String?

    static func build(
        projectName: String? = nil,
        productionState: String? = nil,
        needsAttention: Bool = false,
        attentionReason: String? = nil,
        incidentHeadline: String? = nil,
        incidentCause: String? = nil,
        incidentConfidence: String? = nil,
        envDriftCritical: Int = 0,
        envDriftSummary: String? = nil,
        compareRisk: String? = nil,
        compareSummary: String? = nil,
        runtimeErrorCount: Int? = nil,
        runtimeSummary: String? = nil,
        domainCritical: Int = 0,
        domainSummary: String? = nil,
        polling: Bool = false,
        lastMutatorNote: String? = nil
    ) -> BoundedOpsContext {
        BoundedOpsContext(
            projectName: projectName,
            productionState: productionState,
            needsAttention: needsAttention,
            attentionReason: attentionReason,
            incidentHeadline: incidentHeadline,
            incidentCause: incidentCause,
            incidentConfidence: incidentConfidence,
            envDriftCritical: envDriftCritical,
            envDriftSummary: envDriftSummary,
            compareRisk: compareRisk,
            compareSummary: compareSummary,
            runtimeErrorCount: runtimeErrorCount,
            runtimeSummary: runtimeSummary,
            domainCritical: domainCritical,
            domainSummary: domainSummary,
            polling: polling,
            lastMutatorNote: lastMutatorNote
        )
    }
}

struct OpsNarrative: Sendable {
    var headline: String
    var body: String
    var nextSteps: [String]
    var confidence: IncidentSummary.Confidence
    var usedFields: [String]
    var source: Source

    enum Source: String, Sendable {
        case heuristic
        case appleFoundation = "apple-foundation"
        case hybrid
    }
}

func synthesizeOpsNarrative(_ ctx: BoundedOpsContext) -> OpsNarrative {
    var used: [String] = ["projectName"]
    var next: [String] = []
    var confidence: IncidentSummary.Confidence = .low
    let name = ctx.projectName ?? "this project"

    if ctx.polling {
        used.append("polling")
        return OpsNarrative(
            headline: "Waiting on deploy for \(name)",
            body: "A mutator was accepted and Taktung is polling Vercel. Success is only recorded when state is READY.",
            nextSteps: [
                "Wait for the poll result in Activity",
                "If timeout, refresh deployments and re-check state",
            ],
            confidence: .high,
            usedFields: used,
            source: .heuristic
        )
    }

    var issues: [String] = []
    if ctx.needsAttention {
        used.append(contentsOf: ["needsAttention", "attentionReason", "productionState"])
        issues.append(
            "Needs attention (\(ctx.attentionReason ?? "unknown")). Production state: \(ctx.productionState ?? "unknown")."
        )
        confidence = .medium
    }
    if ctx.incidentCause != nil || ctx.incidentHeadline != nil {
        used.append(contentsOf: ["incidentHeadline", "incidentCause", "incidentConfidence"])
        issues.append(
            "Incident: \(ctx.incidentHeadline ?? "failure"). Likely cause: \(ctx.incidentCause ?? "unknown") (\(ctx.incidentConfidence ?? "low") confidence)."
        )
        if ctx.incidentConfidence == "high" { confidence = .high }
        next.append("Open Diagnose evidence and fix the root cause before redeploy")
    }
    if ctx.envDriftCritical > 0 {
        used.append(contentsOf: ["envDriftCritical", "envDriftSummary"])
        issues.append(
            "Env drift: \(ctx.envDriftCritical) critical finding(s). \(ctx.envDriftSummary ?? "")"
                .trimmingCharacters(in: .whitespaces)
        )
        if confidence == .low { confidence = .medium }
        next.append("Align missing Production env names (values never shown in Taktung)")
    }
    if ctx.domainCritical > 0 {
        used.append(contentsOf: ["domainCritical", "domainSummary"])
        issues.append(
            "Domains: \(ctx.domainCritical) critical. \(ctx.domainSummary ?? "")"
                .trimmingCharacters(in: .whitespaces)
        )
        next.append("Fix DNS / verification in Vercel Domains")
    }
    if ctx.compareRisk == "high" || ctx.compareRisk == "medium" {
        used.append(contentsOf: ["compareRisk", "compareSummary"])
        issues.append(
            "Deploy delta risk \(ctx.compareRisk ?? ""): \(ctx.compareSummary ?? "")"
                .trimmingCharacters(in: .whitespaces)
        )
        next.append("Review commit delta before promote")
    }
    if let count = ctx.runtimeErrorCount, count > 0 {
        used.append(contentsOf: ["runtimeErrorCount", "runtimeSummary"])
        issues.append(
            "Runtime: \(count) error-like line(s). \(ctx.runtimeSummary ?? "")"
                .trimmingCharacters(in: .whitespaces)
        )
        confidence = .medium
        next.append("Inspect top error paths from Runtime 5xx report")
    }
    if ctx.lastMutatorNote != nil { used.append("lastMutatorNote") }

    if issues.isEmpty {
        return OpsNarrative(
            headline: "\(name) looks stable",
            body: "No critical signals in the loaded snapshot. Production state: \(ctx.productionState ?? "unknown"). Load Domain, Env drift, Runtime, or Diagnose for a deeper brief.",
            nextSteps: [
                "Refresh projects if data may be stale",
                "Run Runtime 5xx for production error window",
            ],
            confidence: .medium,
            usedFields: used,
            source: .heuristic
        )
    }
    if next.isEmpty {
        next.append("Refresh deployments and re-run Diagnose on the failing deploy")
    }
    return OpsNarrative(
        headline: "Brief for \(name)",
        body: issues.joined(separator: " "),
        nextSteps: Array(next.prefix(4)),
        confidence: confidence,
        usedFields: used,
        source: .heuristic
    )
}

func formatOpsNarrative(_ n: OpsNarrative) -> String {
    (
        [n.headline, "", n.body, "", "Next steps:"]
            + n.nextSteps.enumerated().map { "\($0.offset + 1). \($0.element)" }
            + ["", "Confidence: \(n.confidence.rawValue)"]
    ).joined(separator: "\n")
}

func containsSecretLike(_ text: String) -> Bool {
    let lowered = text.lowercased()
    if lowered.contains("-----begin") { return true }
    let patterns = ["sk_live", "sk-ant-", "ghp_", "vercel_token=", "aws_secret"]
    return patterns.contains { lowered.contains($0) }
}
