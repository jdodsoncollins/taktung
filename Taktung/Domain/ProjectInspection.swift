import Foundation

struct InspectionScope: Hashable, Sendable {
    var account: EvidenceScope
    var projectID: ProjectID
    var revision: Int
}

enum ProjectTool: String, CaseIterable, Identifiable, Sendable {
    case activity, domains, checks, crons, flags
    var id: String { rawValue }
    var title: String {
        switch self {
        case .activity: "Vercel activity"
        case .domains: "Domains"
        case .checks: "Deployment checks"
        case .crons: "Cron jobs"
        case .flags: "Feature flags"
        }
    }
    var symbol: String {
        switch self {
        case .activity: "clock.arrow.circlepath"
        case .domains: "globe"
        case .checks: "checkmark.shield"
        case .crons: "clock"
        case .flags: "flag"
        }
    }
    var detail: String {
        switch self {
        case .activity: "Deployments, aliases and project changes"
        case .domains: "Domains and ownership verification"
        case .checks: "Configured checks and actual results"
        case .crons: "Configured paths and schedules"
        case .flags: "Flag names and configuration"
        }
    }
}

struct InspectionRow: Identifiable, Sendable, Equatable {
    var id: String
    var title: String
    var detail: String
    var state: String? = nil
    var tone: InspectionTone = .neutral
    var date: Date? = nil
    var category: String = ""
}

enum InspectionTone: Sendable, Equatable { case neutral, ready, warning, error }

struct InspectionResult: Sendable {
    var rows: [InspectionRow]
    var note: String
    var emptyTitle: String
    var fetchedAt: Date = Date()
}

struct InspectionFailure: Sendable {
    var title: String
    var detail: String
    init(_ error: Error) {
        let apiError = error as? VercelAPIError
        switch apiError?.status {
        case 400:
            title = "Vercel rejected the request"
            detail = apiError?.detail ?? "The request was not accepted."
        case 401:
            title = "Reconnect to Vercel"
            detail = "This connection is no longer authorized. Update your token in Settings."
        case 403:
            title = "Access unavailable"
            detail = "Your token, workspace role or Vercel plan does not allow this request."
        case 404:
            title = "Resource unavailable"
            detail = "Vercel did not return this resource for the selected project. Refresh its deployments and try again."
        case 429:
            title = "Vercel rate limit reached"
            detail = "Wait a moment before refreshing this tool."
        case .some(let status) where status >= 500:
            title = "Vercel is unavailable"
            detail = "Vercel returned an error (\(status)). Try again shortly."
        default:
            title = "Couldn’t load evidence"
            if error is URLError || apiError == nil {
                detail = "The request did not complete. Check your connection and try again."
            } else {
                // A response arrived but did not match what Taktung expects. Say so instead of blaming the network.
                detail = apiError?.detail ?? "Vercel returned an unexpected response."
            }
        }
    }
}

struct RuntimeLogEntry: Identifiable, Sendable, Equatable {
    var id: String
    var message: String
    var level: String
    var path: String
    var statusCode: Int?
    var timestamp: Date?
    var isError: Bool { ["error", "fatal"].contains(level) || (statusCode ?? 0) >= 500 }
}

/// Incremental NDJSON/SSE framing. A transport chunk is never treated as a whole record.
struct RuntimeLogDecoder: Sendable {
    static let maximumRecordBytes = 262_144
    private var pending = Data()
    mutating func append(_ byte: UInt8) throws -> RuntimeLogEntry? {
        if byte == 10 {
            let record = pending
            pending.removeAll(keepingCapacity: true)
            return try decode(record)
        }
        guard pending.count < Self.maximumRecordBytes else {
            throw VercelAPIError(status: nil, detail: "A runtime record exceeded the supported size.")
        }
        pending.append(byte)
        return nil
    }
    mutating func finish() throws -> RuntimeLogEntry? {
        defer { pending.removeAll() }
        return try decode(pending)
    }
    private func decode(_ data: Data) throws -> RuntimeLogEntry? {
        var text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text.hasPrefix(":") || text.hasPrefix("event:") { return nil }
        if text.hasPrefix("data:") { text = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
        if text == "[DONE]" { return nil }
        let raw = JSONValue(try JSONSerialization.jsonObject(with: Data(text.utf8)))
        if raw["source"]?.string == "delimiter" { return nil }
        guard let id = raw["rowId"]?.string else {
            throw VercelAPIError.decodeFailed("runtime logs", "missing record identity")
        }
        return RuntimeLogEntry(id: id, message: inspectionText(raw["message"]?.string ?? "", limit: 8_192),
            level: raw["level"]?.string ?? "unknown", path: inspectionPath(raw["requestPath"]?.string ?? ""),
            statusCode: raw["responseStatusCode"]?.double.flatMap { $0.isFinite && (100...599).contains($0) ? Int($0) : nil },
            timestamp: inspectionDate(raw["timestampInMs"]))
    }
}

func inspectionText(_ value: String, limit: Int = 240) -> String {
    String(redactBuildLog(value).prefix(limit))
}

func inspectionPath(_ value: String) -> String {
    // Query strings and fragments can carry credentials; retain only the route.
    inspectionText(String(value.split(separator: "?", maxSplits: 1).first ?? "").split(separator: "#", maxSplits: 1).first.map(String.init) ?? "")
}

func inspectionDate(_ value: JSONValue?) -> Date? {
    if let ms = value?.double, ms.isFinite, ms > 0 { return Date(timeIntervalSince1970: ms / 1_000) }
    if let string = value?.string {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
    return nil
}

func checkPresentation(status: String?, conclusion: String?) -> (String, InspectionTone) {
    guard status == "completed" else {
        switch status {
        case "running": return ("Running", .warning)
        case "registered": return ("Pending", .neutral)
        default: return ("Status unavailable", .neutral)
        }
    }
    switch conclusion {
    case "succeeded": return ("Passed", .ready)
    case "failed": return ("Failed", .error)
    case "canceled": return ("Canceled", .neutral)
    case "skipped": return ("Skipped", .neutral)
    case "neutral": return ("Neutral", .neutral)
    case "stale": return ("Stale", .warning)
    default: return ("Result unavailable", .neutral)
    }
}

func filterInspectionRows(_ rows: [InspectionRow], query: String, category: String = "All") -> [InspectionRow] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return rows.filter { row in
        (category == "All" || row.category == category) &&
        (q.isEmpty || [row.title, row.detail, row.state ?? ""].contains { $0.localizedCaseInsensitiveContains(q) })
    }
}
