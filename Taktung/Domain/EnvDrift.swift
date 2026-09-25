import Foundation

enum EnvDriftKind: String, Sendable {
    case missingInProduction = "missing_in_production"
    case missingInPreview = "missing_in_preview"
    case targetMismatch = "target_mismatch"
    case staleNameHint = "stale_name_hint"
}

struct EnvDriftFinding: Sendable, Hashable, Identifiable {
    var id: String { "\(kind.rawValue):\(key)" }
    var kind: EnvDriftKind
    var key: String
    var detail: String
    var severity: Severity

    enum Severity: String, Sendable {
        case info
        case warning
        case critical
    }
}

struct EnvDriftReport: Sendable {
    var findings: [EnvDriftFinding]
    /// Keys present — never values.
    var productionKeys: [String]
    var previewKeys: [String]
    var developmentKeys: [String]
    var summary: String
}

/// Compare env var *names* across targets. Never include secret values.
func analyzeEnvDrift(_ vars: [EnvVarMeta]) -> EnvDriftReport {
    func targets(_ target: String) -> Set<String> {
        Set(
            vars.filter { $0.target.contains { $0.lowercased() == target.lowercased() } }
                .map(\.key)
        )
    }
    let productionKeys = targets("production").sorted()
    let previewKeys = targets("preview").sorted()
    let developmentKeys = targets("development").sorted()
    var findings: [EnvDriftFinding] = []
    let prod = Set(productionKeys)
    let prev = Set(previewKeys)

    for key in previewKeys where !prod.contains(key) {
        findings.append(
            EnvDriftFinding(
                kind: .missingInProduction,
                key: key,
                detail: "Present in Preview but missing in Production: \(key)",
                severity: .critical
            )
        )
    }
    if !previewKeys.isEmpty {
        for key in productionKeys where !prev.contains(key) {
            findings.append(
                EnvDriftFinding(
                    kind: .missingInPreview,
                    key: key,
                    detail: "Present in Production but missing in Preview: \(key)",
                    severity: .warning
                )
            )
        }
    }

    let allKeys = Set(vars.map(\.key))
    for key in allKeys where key.hasSuffix("_OLD") || key.hasSuffix("_LEGACY") {
        let base = key.replacingOccurrences(of: "_OLD", with: "")
            .replacingOccurrences(of: "_LEGACY", with: "")
        if allKeys.contains(base) {
            findings.append(
                EnvDriftFinding(
                    kind: .staleNameHint,
                    key: key,
                    detail: "Possible stale variable name: \(key) coexists with \(base)",
                    severity: .info
                )
            )
        }
    }

    var byKey: [String: [EnvVarMeta]] = [:]
    for v in vars { byKey[v.key, default: []].append(v) }
    for (key, entries) in byKey where entries.count > 1 {
        let types = Set(entries.map(\.type))
        if types.count > 1 {
            findings.append(
                EnvDriftFinding(
                    kind: .targetMismatch,
                    key: key,
                    detail: "Variable \(key) has mixed types: \(types.sorted().joined(separator: ", "))",
                    severity: .info
                )
            )
        }
    }

    let critical = findings.filter { $0.severity == .critical }.count
    let warning = findings.filter { $0.severity == .warning }.count
    let summary: String
    if findings.isEmpty {
        summary =
            "No env drift detected across \(productionKeys.count) production and \(previewKeys.count) preview keys."
    } else {
        summary = "\(findings.count) finding(s): \(critical) critical, \(warning) warning. Values are never shown."
    }
    return EnvDriftReport(
        findings: findings,
        productionKeys: productionKeys,
        previewKeys: previewKeys,
        developmentKeys: developmentKeys,
        summary: summary
    )
}
