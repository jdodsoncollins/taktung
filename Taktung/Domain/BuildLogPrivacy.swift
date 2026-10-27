import Foundation

/// Strip assignments and common credential formats before logs enter UI or analysis.
private let buildLogRedactions: [NSRegularExpression] = [
        #"\b(?:(?i:process\.env\.))?[A-Z][A-Z0-9_]{2,}\s*[=:]\s*(?:"[^"]*"|'[^']*'|[^\s,;]+)"#,
        #""[A-Z][A-Z0-9_]{2,}"\s*:\s*"[^"]*""#,
        #"(?i)\bBearer\s+\S+"#,
        #"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b"#,
        #"\b(?:sk_|pk_live_|ghp_|vcp_|vercel_)[A-Za-z0-9_-]{12,}\b"#,
        #"(?i)(?:postgres(?:ql)?|mysql|mongodb(?:\+srv)?|https?)://[^\s/@]+:[^\s/@]+@[^\s]+"#,
        #"(?i)["']?\b(?:access[_-]?token|api[_-]?key|client[_-]?secret|password|passwd|authorization|cookie|set-cookie)["']?\s*[=:]\s*(?:"[^"]*"|'[^']*'|[^\s,;]+)"#,
        #"https?://[^\s"'<>]+\?[^\s"'<>]+"#,
    ].map { try! NSRegularExpression(pattern: $0) }

private let terminalEscape = try! NSRegularExpression(pattern: #"\x1B\[[0-?]*[ -/]*[@-~]"#)

func redactBuildLog(_ text: String) -> String {
    var result = terminalEscape.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    for regex in buildLogRedactions {
        result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result),
                                                withTemplate: "[REDACTED]")
    }
    return result
}
