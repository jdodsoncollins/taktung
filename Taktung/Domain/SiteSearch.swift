import Foundation

/// What a Search request asks for. Deployment plans run as live Vercel
/// requests for one site; site plans refer only to loaded projects.
/// Site matches are resolved before state words, so a site named "ready" stays a site.
enum SiteSearchPlan: Hashable {
    case sites([VercelProject])
    case deployments(DeploymentQuery)
    /// The request names a loaded site other than the selected one.
    case otherSite(VercelProject, DeploymentQuery)
    case environment
    case chooseSite
    case noMatch
}

enum SearchInterpreter: Hashable, Sendable {
    case rules
    case appleIntelligence
}

struct SiteSearchInterpretation: Hashable {
    var plan: SiteSearchPlan
    /// Words the rules could not place. When present, the on-device model may
    /// interpret the request; otherwise they become a commit-text filter.
    var unresolved: [String] = []
    var interpreter: SearchInterpreter = .rules
    var needsModel: Bool { !unresolved.isEmpty }
}

func planSiteSearch(_ query: String, projects: [VercelProject], selectedProjectID: ProjectID?) -> SiteSearchInterpretation {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let q = trimmed.lowercased()
    guard !q.isEmpty else { return .init(plan: .noMatch) }
    let host = URLComponents(string: q.contains("://") ? q : "https://\(q)")?.host
    let exact = projects.filter { project in
        let names = [project.name.lowercased(), siteTitle(project).lowercased(), siteRepoLabel(project)?.lowercased()]
        return names.contains(q) || (host == q || q.contains("://")) && siteTitle(project).lowercased() == host
    }
    if !exact.isEmpty { return .init(plan: .sites(rankSites(exact))) }

    var parsed = SearchRules.parse(trimmed, projects: projects)
    if parsed.environment {
        return .init(plan: selectedProjectID == nil ? .chooseSite : .environment)
    }
    if parsed.hasDeploymentSignal {
        let unresolved = parsed.unresolved
        if !unresolved.isEmpty, parsed.query.text == nil { parsed.query.text = unresolved.joined(separator: " ") }
        return .init(plan: deploymentPlan(parsed.query, site: parsed.site, selectedProjectID: selectedProjectID),
                     unresolved: unresolved)
    }
    let matches = rankSites(projects, query: q)
    if !matches.isEmpty { return .init(plan: .sites(matches)) }
    // Free text searches commit messages, branches and authors of the selected site.
    guard selectedProjectID != nil, !parsed.unresolved.isEmpty else { return .init(plan: .noMatch, unresolved: parsed.unresolved) }
    return .init(plan: .deployments(DeploymentQuery(text: parsed.unresolved.joined(separator: " "))), unresolved: parsed.unresolved)
}

func deploymentPlan(_ query: DeploymentQuery, site: VercelProject?, selectedProjectID: ProjectID?) -> SiteSearchPlan {
    if let site, site.id != selectedProjectID { return .otherSite(site, query) }
    return selectedProjectID == nil ? .chooseSite : .deployments(query)
}

/// Deterministic vocabulary for deployment requests. It runs before, and
/// without, Apple Intelligence; the model only interprets leftover words.
enum SearchRules {
    struct Parsed {
        var query = DeploymentQuery()
        var site: VercelProject?
        var environment = false
        var deploymentNoun = false
        var unresolved: [String] = []

        var hasDeploymentSignal: Bool { deploymentNoun || query.hasFilters || query.limit != DeploymentQuery.defaultLimit }
    }

    static let readyWords: Set<String> = ["ready", "success", "successes", "successful", "successfully", "succeeded", "succeed",
        "passed", "passing", "green", "good", "working", "worked", "completed", "complete", "finished", "done",
        "healthy", "shipped", "ok", "okay"]
    static let failedWords: Set<String> = ["failed", "failing", "fail", "fails", "failure", "failures", "unsuccessful",
        "error", "errors", "errored", "erroring", "broken", "broke", "breaking", "crashed", "crash", "crashes", "red", "bad"]
    static let canceledWords: Set<String> = ["canceled", "cancelled", "cancel", "cancels", "aborted", "stopped"]
    static let blockedWords: Set<String> = ["blocked"]
    static let buildingWords: Set<String> = ["building", "queued", "queue", "pending", "running", "deploying",
        "initializing", "ongoing", "in-progress", "inprogress", "unfinished"]
    static let productionWords: Set<String> = ["production", "prod", "live"]
    static let previewWords: Set<String> = ["preview", "previews"]
    static let deploymentNouns: Set<String> = ["deploy", "deploys", "deployment", "deployments", "deployed",
        "build", "builds", "release", "releases", "commit", "commits", "push", "pushes"]
    static let singularNouns: Set<String> = ["deploy", "deployment", "build", "release", "commit", "push"]
    static let environmentWords: Set<String> = ["env", "envs", "variable", "variables", "vars", "var", "drift"]
    static let generalEnvironmentWords: Set<String> = ["environment", "environments"]
    static let newestWords: Set<String> = ["latest", "newest", "last", "recent", "most"]
    static let commonBranches: Set<String> = ["main", "master", "develop", "development", "trunk", "staging", "canary"]
    static let negationWords: Set<String> = ["not", "no", "non", "didn't", "didnt", "never", "without", "except",
        "excluding", "isn't", "isnt", "wasn't", "wasnt", "aren't", "arent", "weren't", "werent", "hasn't", "haven't"]
    static let noiseWords: Set<String> = ["show", "me", "list", "find", "get", "give", "see", "view", "display", "open",
        "all", "any", "every", "the", "a", "an", "my", "our", "your", "of", "for", "with", "that", "which", "what",
        "whats", "what's", "when", "where", "who", "were", "was", "are", "is", "be", "been", "being", "did", "do",
        "does", "have", "has", "had", "to", "in", "at", "by", "from", "on", "and", "or", "only", "just", "site",
        "project", "app", "vercel", "there", "how", "many", "much", "recently", "ones", "one", "those", "these", "i",
        "we", "you", "it", "its", "it's", "status", "state", "states", "top", "first", "about", "happened", "happen",
        "went", "go", "look", "up", "search", "can", "could", "would", "should", "will", "within", "during", "over",
        "new", "so", "far", "time", "times", "made", "created", "triggered", "please", "check", "lately", "out",
        "since", "ago", "branch", "branches", "this", "past", "right", "now", "currently", "current", "moment"]
    static let timeUnits: [String: (hours: Int, days: Int)] = [
        "hour": (1, 0), "hours": (1, 0), "hr": (1, 0), "hrs": (1, 0), "h": (1, 0),
        "day": (0, 1), "days": (0, 1), "d": (0, 1),
        "week": (0, 7), "weeks": (0, 7), "wk": (0, 7), "wks": (0, 7), "w": (0, 7),
        "month": (0, 30), "months": (0, 30),
    ]

    static let vocabulary: Set<String> = {
        readyWords.union(failedWords).union(canceledWords).union(blockedWords).union(buildingWords)
            .union(productionWords).union(previewWords).union(deploymentNouns).union(environmentWords)
            .union(generalEnvironmentWords).union(newestWords).union(negationWords).union(noiseWords)
            .union(["today", "tonight", "yesterday", "overnight", "week", "month"])
    }()

    static func parse(_ text: String, projects: [VercelProject]) -> Parsed {
        var parsed = Parsed()
        var remaining = text
        // Quoted text is an explicit commit-text filter.
        if let quoted = firstQuoted(in: text) {
            parsed.query.text = quoted.text
            remaining.removeSubrange(quoted.range)
        }
        let tokens = tokenize(remaining)
        var states: Set<DeploymentState> = []
        var negatedStates: Set<DeploymentState> = []
        var negation = 0
        var newest = false
        var singular = false
        var limit: Int?
        var specificEnvironment = false
        var generalEnvironment = false
        var i = 0
        func token(_ offset: Int) -> String? { tokens.indices.contains(i + offset) ? tokens[i + offset] : nil }

        while i < tokens.count {
            let t = tokens[i]
            var consumed = 1
            var negates = false
            if negationWords.contains(t) {
                negation = 3
                negates = true
            } else if let group = stateGroup(t) {
                if negation > 0 { negatedStates.formUnion(group) } else { states.formUnion(group) }
            } else if t == "in", token(1) == "progress" || token(1) == "flight" {
                states.formUnion(DeploymentQuery.inFlightStates)
                consumed = 2
            } else if productionWords.contains(t) {
                parsed.query.target = .production
            } else if previewWords.contains(t) {
                parsed.query.target = .preview
            } else if t == "branch", let next = token(1), isBranchLike(next), !vocabulary.contains(next) {
                parsed.query.branch = next
                consumed = 2
            } else if let next = token(1), next == "branch", isBranchLike(t), !vocabulary.contains(t) || commonBranches.contains(t) {
                parsed.query.branch = t
                consumed = 2
            } else if (t == "on" || t == "from"), let next = token(1), isBranchLike(next),
                      commonBranches.contains(next) || next.contains("/") {
                parsed.query.branch = next
                consumed = 2
            } else if commonBranches.contains(t) {
                parsed.query.branch = t
            } else if isCommitSHA(t) {
                parsed.query.sha = t
            } else if let match = timeWindow(at: i, in: tokens) {
                parsed.query.window = match.window
                consumed = match.length
            } else if newestWords.contains(t) {
                newest = true
                if let next = token(1), let n = Int(next), (1...DeploymentQuery.maximumLimit).contains(n) {
                    limit = n
                    consumed = 2
                }
            } else if let n = Int(t) {
                if (1...DeploymentQuery.maximumLimit).contains(n) { limit = n } else { parsed.unresolved.append(t) }
            } else if deploymentNouns.contains(t) {
                parsed.deploymentNoun = true
                if singularNouns.contains(t) { singular = true }
            } else if environmentWords.contains(t) {
                specificEnvironment = true
            } else if generalEnvironmentWords.contains(t) {
                generalEnvironment = true
            } else if noiseWords.contains(t) {
                // Grammar only.
            } else if let site = singleSite(t, projects: projects) {
                parsed.site = site
            } else {
                parsed.unresolved.append(t)
            }
            if !negates { negation = max(0, negation - consumed) }
            i += consumed
        }

        if !negatedStates.isEmpty {
            let groups: [Set<DeploymentState>] = [[.ready], DeploymentQuery.failedStates, DeploymentQuery.inFlightStates]
            for group in groups where group.isDisjoint(with: negatedStates) { states.formUnion(group) }
        }
        parsed.query.states = states
        if let limit { parsed.query.limit = limit } else if newest && singular { parsed.query.limit = 1 }
        // "Production environment" describes deployments; "env vars" asks for the variable check.
        parsed.environment = specificEnvironment || (generalEnvironment && !parsed.hasDeploymentSignal)
        return parsed
    }

    static func stateGroup(_ word: String) -> Set<DeploymentState>? {
        if readyWords.contains(word) { return [.ready] }
        if failedWords.contains(word) { return DeploymentQuery.failedStates }
        if canceledWords.contains(word) { return [.canceled] }
        if blockedWords.contains(word) { return [.blocked] }
        if buildingWords.contains(word) { return DeploymentQuery.inFlightStates }
        return nil
    }

    /// Recognizes "today", "yesterday", "this week", "last 3 days", "past hour", "24h" and similar.
    static func timeWindow(at index: Int, in tokens: [String]) -> (window: SearchWindow, length: Int)? {
        let t = tokens[index]
        let next = tokens.indices.contains(index + 1) ? tokens[index + 1] : nil
        let after = tokens.indices.contains(index + 2) ? tokens[index + 2] : nil
        switch t {
        case "today", "tonight": return (.today, 1)
        case "yesterday": return (.yesterday, 1)
        case "overnight": return (.lastHours(12), 1)
        case "this":
            if next == "week" { return (.thisWeek, 2) }
            if next == "month" { return (.thisMonth, 2) }
            return nil
        case "last", "past":
            if let next, let unit = timeUnits[next] { return (window(1, unit), 2) }
            if let next, let n = Int(next), let after, let unit = timeUnits[after], n > 0 { return (window(n, unit), 3) }
            if let next, let compact = compactDuration(next) { return (compact, 2) }
            return nil
        default:
            if let compact = compactDuration(t) { return (compact, 1) }
            if let n = Int(t), n > 0, let next, let unit = timeUnits[next] { return (window(n, unit), 2) }
            return nil
        }
    }

    private static func window(_ n: Int, _ unit: (hours: Int, days: Int)) -> SearchWindow {
        unit.hours > 0 ? .lastHours(min(n * unit.hours, 24 * 30)) : .lastDays(min(n * unit.days, 365))
    }

    /// "24h", "7d", "2w".
    private static func compactDuration(_ token: String) -> SearchWindow? {
        guard let unit = token.last, ["h", "d", "w"].contains(unit),
              let n = Int(token.dropLast()), n > 0 else { return nil }
        switch unit {
        case "h": return .lastHours(min(n, 24 * 30))
        case "d": return .lastDays(min(n, 365))
        default: return .lastDays(min(n * 7, 365))
        }
    }

    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ";" })
            .map { word in
                var w = String(word).trimmingCharacters(in: CharacterSet(charactersIn: "?!.:;\"“”‘’()[]{}"))
                w = w.replacingOccurrences(of: "’", with: "'")
                if w.hasSuffix("'s"), w.count > 2 { w.removeLast(2) }
                return w
            }
            .filter { !$0.isEmpty }
    }

    static func firstQuoted(in text: String) -> (text: String, range: Range<String.Index>)? {
        for (open, close) in [("\"", "\""), ("“", "”")] {
            guard let start = text.range(of: open),
                  let end = text.range(of: close, range: start.upperBound..<text.endIndex) else { continue }
            let inner = text[start.upperBound..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty { return (inner, start.lowerBound..<end.upperBound) }
        }
        return nil
    }

    static func isBranchLike(_ token: String) -> Bool {
        token.count <= 100 && token.range(of: #"^[a-z0-9][a-z0-9._/-]*$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func isCommitSHA(_ token: String) -> Bool {
        (7...40).contains(token.count) && token.allSatisfy(\.isHexDigit) && token.contains(where: \.isNumber)
            && token.contains(where: \.isLetter)
    }

    private static func singleSite(_ token: String, projects: [VercelProject]) -> VercelProject? {
        let bare = { (name: String) in name.lowercased().hasPrefix("www.") ? String(name.lowercased().dropFirst(4)) : name.lowercased() }
        let matches = projects.filter { bare($0.name) == bare(token) || bare(siteTitle($0)) == bare(token) }
        return matches.count == 1 ? matches[0] : nil
    }
}
