import Foundation

enum AnalyticsPeriod: Int, CaseIterable, Identifiable, Sendable {
    case week = 7, month = 30
    var id: Int { rawValue }
    var title: String { "Last \(rawValue) days" }

    func window(now: Date = Date()) -> AnalyticsWindow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let end = calendar.startOfDay(for: now)
        return AnalyticsWindow(since: calendar.date(byAdding: .day, value: -rawValue, to: end)!, until: end)
    }
}

struct AnalyticsWindow: Hashable, Sendable {
    let since: Date
    /// Exclusive end. Aggregate requests use one millisecond before this boundary.
    let until: Date
    var label: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt)
        return "\(since.formatted(style)) – \(until.addingTimeInterval(-0.001).formatted(style)) · UTC"
    }
}

struct AnalyticsCounts: Equatable, Sendable {
    let visitors: Int
    let pageviews: Int
}

struct AnalyticsDay: Identifiable, Equatable, Sendable {
    let date: Date
    let counts: AnalyticsCounts
    var id: Date { date }
}

struct AnalyticsOverview: Sendable {
    let window: AnalyticsWindow
    let counts: AnalyticsCounts
    let days: [AnalyticsDay]
    var fetchedAt = Date()
}

enum AnalyticsDimension: String, CaseIterable, Identifiable, Sendable {
    case pages = "requestPath", referrers = "referrerHostname", countries = "country", devices = "deviceType"
    var id: String { rawValue }
    var title: String {
        switch self { case .pages: "Pages"; case .referrers: "Referrers"; case .countries: "Countries"; case .devices: "Devices" }
    }
    func label(_ value: String) -> String {
        if value == "Others" { return "Others" }
        if value.isEmpty { return self == .referrers ? "Direct / unknown" : "Unknown" }
        switch self {
        case .pages: return inspectionPath(value)
        case .referrers: return inspectionText(value.components(separatedBy: "?")[0], limit: 160)
        case .countries: return Locale.current.localizedString(forRegionCode: value) ?? inspectionText(value)
        case .devices: return inspectionText(value).capitalized
        }
    }
}

struct AnalyticsSegment: Identifiable, Equatable, Sendable {
    let key: String
    let counts: AnalyticsCounts
    var id: String { key }
}

enum AnalyticsContract {
    static func date(_ value: JSONValue?) -> Date? {
        guard let string = value?.string else { return nil }
        return ISO8601DateFormatter().date(from: string) ?? {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: string)
        }()
    }

    static func counts(_ raw: JSONValue?) throws -> AnalyticsCounts {
        guard let visitors = raw?["visitors"]?.double, let views = raw?["pageviews"]?.double,
              visitors.isFinite, views.isFinite, visitors >= 0, views >= 0,
              visitors < Double(Int.max), views < Double(Int.max),
              visitors.rounded() == visitors, views.rounded() == views else { throw invalid() }
        return AnalyticsCounts(visitors: Int(visitors), pageviews: Int(views))
    }

    static func window(_ raw: JSONValue, within requested: AnalyticsWindow) throws -> AnalyticsWindow {
        guard let since = date(raw["query"]?["since"]), let until = date(raw["query"]?["until"]),
              since < until, since >= requested.since, until <= requested.until else { throw invalid() }
        return AnalyticsWindow(since: since, until: until)
    }

    static func days(_ raw: JSONValue, window: AnalyticsWindow) throws -> [AnalyticsDay] {
        guard try self.window(raw, within: window) == window,
              let rows = raw["data"]?.array, rows.count <= 32 else { throw invalid() }
        var seen = Set<Date>()
        return try rows.map { row in
            guard let date = date(row["timestamp"]), date >= window.since, date < window.until,
                  seen.insert(date).inserted else { throw invalid() }
            return AnalyticsDay(date: date, counts: try counts(row))
        }.sorted { $0.date < $1.date }
    }

    static func segments(_ raw: JSONValue, dimension: AnalyticsDimension, window: AnalyticsWindow) throws -> [AnalyticsSegment] {
        guard try self.window(raw, within: window) == window,
              let rows = raw["data"]?.array, rows.count <= 11 else { throw invalid() }
        var seen = Set<String>()
        return try rows.map { row in
            // A null referrer is a meaningful direct/unknown bucket, not an absent count.
            guard let value = row[dimension.rawValue] else { throw invalid() }
            let key: String
            if case .null = value { key = "" }
            else if let string = value.string { key = string }
            else { throw invalid() }
            guard seen.insert(key).inserted else { throw invalid() }
            return AnalyticsSegment(key: key, counts: try counts(row))
        }.sorted {
            if $0.key == "Others" { return false }
            if $1.key == "Others" { return true }
            return $0.counts.pageviews > $1.counts.pageviews
        }
    }

    static func invalid() -> VercelAPIError {
        VercelAPIError(status: nil, detail: "Analytics response did not match its reporting window or expected counts.")
    }
}
