import Foundation

/// A deployment search for one selected site, expressed in the filters that
/// `GET /v7/deployments` accepts. Commit text has no server filter, so it is
/// matched on the device over a bounded newest-first window.
struct DeploymentQuery: Hashable, Sendable {
    var states: Set<DeploymentState> = []
    var target: DeploymentTarget?
    var branch: String?
    /// A full SHA is sent to Vercel; a shorter prefix is matched on the device.
    var sha: String?
    var window: SearchWindow?
    var text: String?
    var limit: Int = DeploymentQuery.defaultLimit

    static let defaultLimit = 20
    static let maximumLimit = 100
    /// States Vercel's list endpoint can filter on.
    static let filterableStates: Set<DeploymentState> = [.ready, .error, .canceled, .blocked, .building, .initializing, .queued]
    static let failedStates: Set<DeploymentState> = [.error, .canceled, .blocked]
    static let inFlightStates: Set<DeploymentState> = [.building, .initializing, .queued]

    var hasFilters: Bool {
        !states.isEmpty || target != nil || branch != nil || sha != nil || window != nil || text != nil
    }

    /// How many records to request: commit text and short SHAs are matched
    /// locally, so they need a wider newest-first window than they display.
    var fetchLimit: Int {
        text != nil || sha.map(isShortSHA) == true ? Self.maximumLimit : min(max(1, limit), Self.maximumLimit)
    }

    func apiParameters(now: Date = Date(), calendar: Calendar = .current) -> [String: String] {
        var query: [String: String] = [:]
        let states = states.intersection(Self.filterableStates)
        if !states.isEmpty { query["state"] = states.map(\.rawValue).sorted().joined(separator: ",") }
        if let target { query["target"] = target.rawValue }
        if let branch { query["branch"] = branch }
        if let sha, !isShortSHA(sha) { query["sha"] = sha }
        if let bounds = window?.bounds(now: now, calendar: calendar) {
            query["since"] = String(Int64(bounds.since.timeIntervalSince1970 * 1000))
            if let until = bounds.until { query["until"] = String(Int64(until.timeIntervalSince1970 * 1000)) }
        }
        return query
    }

    /// Applies every filter locally. Live results are checked again so a
    /// filter the server ignored can never widen what the app reports.
    func matches(_ d: VercelDeploymentSummary, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        if !states.isEmpty, !states.contains(d.state) { return false }
        switch target {
        case .production?: if d.target != .production { return false }
        case .preview?: if d.target != .preview && d.target != nil { return false }
        case .development?: if d.target != .development { return false }
        case nil: break
        }
        if let branch, d.meta.githubCommitRef?.caseInsensitiveCompare(branch) != .orderedSame { return false }
        if let sha, d.meta.githubCommitSha?.lowercased().hasPrefix(sha.lowercased()) != true { return false }
        if let bounds = window?.bounds(now: now, calendar: calendar) {
            let created = Date(timeIntervalSince1970: d.createdAt / 1000)
            if created < bounds.since { return false }
            if let until = bounds.until, created >= until { return false }
        }
        if let text {
            // Every word must appear somewhere, in any order.
            let fields = [d.meta.githubCommitMessage, d.meta.githubCommitRef, d.meta.githubCommitSha,
                          d.meta.githubCommitAuthorLogin, d.meta.githubCommitAuthorName, d.creatorUsername, d.url]
                .compactMap { $0 }.joined(separator: "\n")
            let words = text.split(whereSeparator: \.isWhitespace)
            if !words.allSatisfy({ fields.localizedCaseInsensitiveContains($0) }) { return false }
        }
        return true
    }

    var stateLabel: String? {
        if states.isEmpty { return nil }
        if states == [.ready] { return "Ready" }
        if states == Self.failedStates || states.isSubset(of: [.error, .blocked]) && states.contains(.error) { return "Failed" }
        if states == [.canceled] { return "Canceled" }
        if states == [.blocked] { return "Blocked" }
        if states.isSubset(of: Self.inFlightStates) { return "Building" }
        if states == Self.inFlightStates.union([.ready]) { return "Not failed" }
        return states.map { $0.rawValue.capitalized }.sorted().joined(separator: " or ")
    }

    var title: String {
        var words = [stateLabel, target.map { $0.rawValue.capitalized }].compactMap { $0 }
        if limit == 1 { words.insert("Latest", at: 0) }
        words.append(limit == 1 ? "deployment" : "deployments")
        let first = words[0].prefix(1).uppercased() + words[0].dropFirst()
        return ([first] + words.dropFirst().map { $0.lowercased() }).joined(separator: " ")
    }

    /// Each applied filter, in a stable order, for removable chips.
    var filters: [DeploymentQueryFilter] {
        var list: [DeploymentQueryFilter] = []
        if let stateLabel { list.append(.init(kind: .state, label: stateLabel)) }
        if let target { list.append(.init(kind: .target, label: target.rawValue.capitalized)) }
        if let branch { list.append(.init(kind: .branch, label: "Branch \(branch)")) }
        if let sha { list.append(.init(kind: .sha, label: "Commit \(sha.prefix(7))")) }
        if let window { list.append(.init(kind: .window, label: window.label)) }
        if let text { list.append(.init(kind: .text, label: "“\(text)”")) }
        if limit != Self.defaultLimit { list.append(.init(kind: .limit, label: limit == 1 ? "Newest only" : "Newest \(limit)")) }
        return list
    }

    func removing(_ kind: DeploymentQueryFilter.Kind) -> DeploymentQuery {
        var copy = self
        switch kind {
        case .state: copy.states = []
        case .target: copy.target = nil
        case .branch: copy.branch = nil
        case .sha: copy.sha = nil
        case .window: copy.window = nil
        case .text: copy.text = nil
        case .limit: copy.limit = Self.defaultLimit
        }
        return copy
    }

    /// Honest coverage for the result caption: the server filters the whole
    /// history, but local text matching only sees the newest window.
    var coverage: String {
        if text != nil || sha.map(isShortSHA) == true {
            return "Matched on this device within the newest \(Self.maximumLimit) results Vercel returned."
        }
        return limit == 1 ? "Newest match from Vercel." : "Newest \(limit) matches from Vercel."
    }
}

struct DeploymentQueryFilter: Hashable, Identifiable {
    enum Kind: Hashable { case state, target, branch, sha, window, text, limit }
    var kind: Kind
    var label: String
    var id: Kind { kind }
}

enum SearchWindow: Hashable, Sendable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case lastHours(Int)
    case lastDays(Int)

    func bounds(now: Date, calendar: Calendar) -> (since: Date, until: Date?) {
        switch self {
        case .today:
            return (calendar.startOfDay(for: now), nil)
        case .yesterday:
            let today = calendar.startOfDay(for: now)
            return (calendar.date(byAdding: .day, value: -1, to: today) ?? today, today)
        case .thisWeek:
            return (calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now), nil)
        case .thisMonth:
            return (calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now), nil)
        case .lastHours(let hours):
            return (now.addingTimeInterval(-Double(hours) * 3_600), nil)
        case .lastDays(let days):
            return (now.addingTimeInterval(-Double(days) * 86_400), nil)
        }
    }

    var label: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "This week"
        case .thisMonth: "This month"
        case .lastHours(let h): h == 1 ? "Last hour" : "Last \(h) hours"
        case .lastDays(let d): d == 1 ? "Last 24 hours" : "Last \(d) days"
        }
    }
}

func isShortSHA(_ sha: String) -> Bool { sha.count < 40 }
