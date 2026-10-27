import Foundation

/// A bounded, secret-free summary of a widget scope's most recent 20 deployments.
/// Counts describe this sample, not all-time totals or the current production target.
struct WidgetDeploymentSnapshot: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable { case live, demo }

    struct Latest: Codable, Equatable, Sendable {
        var id: String
        var state: DeploymentState
        var target: DeploymentTarget?
        var createdAt: Date
        var projectName: String? = nil
    }

    static let sampleLimit = 20
    var schema = 1
    var revision: String
    var accountID: String
    var teamID: String?
    var projectID: String
    var projectName: String
    var source: Source
    var checkedAt: Date
    var total: Int
    var ready: Int
    var failed: Int
    var building: Int
    var latest: Latest?
    var events: [Latest] = []

    private enum CodingKeys: String, CodingKey {
        case schema, revision, accountID, teamID, projectID, projectName, source, checkedAt
        case total, ready, failed, building, latest, events
    }

    var isValid: Bool {
        schema == 1 && !revision.isEmpty && !accountID.isEmpty && !projectID.isEmpty
        && !projectName.isEmpty && (0...Self.sampleLimit).contains(total)
        && ready >= 0 && failed >= 0 && building >= 0
        && ready + failed + building <= total
        && ((total == 0 && latest == nil) || (total > 0 && latest != nil))
        && events.count <= 5 && events.count <= total
        && Set(events.map(\.id)).count == events.count
        && events.allSatisfy { !$0.id.isEmpty && $0.createdAt.timeIntervalSince1970.isFinite }
    }

    func isSameScope(as other: Self) -> Bool {
        revision == other.revision && accountID == other.accountID
        && teamID == other.teamID && projectID == other.projectID && source == other.source
    }

    static func make(projectID: String, projectName: String, accountID: String,
                     teamID: String?, revision: String, source: Source,
                     deployments: [VercelDeploymentSummary], now: Date = Date()) -> Self {
        var seen = Set<String>()
        let sample = deployments.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt > $1.createdAt
        }.filter { seen.insert($0.id).inserted }.prefix(sampleLimit)
        let latest = sample.first.map {
            Latest(id: $0.id, state: $0.state, target: $0.target,
                   createdAt: Date(timeIntervalSince1970: $0.createdAt / 1_000),
                   projectName: String($0.name.prefix(120)))
        }
        return Self(revision: revision, accountID: accountID, teamID: teamID,
                    projectID: projectID, projectName: String(projectName.prefix(120)), source: source,
                    checkedAt: now, total: sample.count,
                    ready: sample.filter { $0.state == .ready }.count,
                    failed: sample.filter { [.error, .blocked, .canceled].contains($0.state) }.count,
                    building: sample.filter { [.building, .queued, .initializing].contains($0.state) }.count,
                    latest: latest, events: sample.prefix(5).map {
                        Latest(id: $0.id, state: $0.state, target: $0.target,
                               createdAt: Date(timeIntervalSince1970: $0.createdAt / 1_000),
                               projectName: String($0.name.prefix(120)))
                    })
    }

    /// Widget gallery only; never a fallback for a live account.
    static func gallery(now: Date = Date()) -> Self {
        var snapshot = Self(revision: "gallery", accountID: "gallery", projectID: "gallery",
             projectName: "All projects", source: .demo, checkedAt: now,
             total: 20, ready: 16, failed: 1, building: 1,
             latest: Latest(id: "gallery", state: .ready, target: .production,
                            createdAt: now.addingTimeInterval(-720), projectName: "example-portfolio"))
        snapshot.events = [snapshot.latest!] + [
            Latest(id: "gallery-canceled", state: .canceled, target: .preview, createdAt: now.addingTimeInterval(-2160), projectName: "example-docs"),
            Latest(id: "gallery-deleted", state: .deleted, target: .preview, createdAt: now.addingTimeInterval(-3120), projectName: "example-portfolio"),
            Latest(id: "gallery-building", state: .building, target: .preview, createdAt: now.addingTimeInterval(-4200), projectName: "example-store"),
            Latest(id: "gallery-unknown", state: .unknown, target: .preview, createdAt: now.addingTimeInterval(-5400), projectName: "example-blog")
        ]
        return snapshot
    }
}

extension WidgetDeploymentSnapshot {
    /// Preserve small/medium caches written before the large-widget activity list existed.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(schema: try values.decode(Int.self, forKey: .schema),
                  revision: try values.decode(String.self, forKey: .revision),
                  accountID: try values.decode(String.self, forKey: .accountID),
                  teamID: try values.decodeIfPresent(String.self, forKey: .teamID),
                  projectID: try values.decode(String.self, forKey: .projectID),
                  projectName: try values.decode(String.self, forKey: .projectName),
                  source: try values.decode(Source.self, forKey: .source),
                  checkedAt: try values.decode(Date.self, forKey: .checkedAt),
                  total: try values.decode(Int.self, forKey: .total),
                  ready: try values.decode(Int.self, forKey: .ready),
                  failed: try values.decode(Int.self, forKey: .failed),
                  building: try values.decode(Int.self, forKey: .building),
                  latest: try values.decodeIfPresent(Latest.self, forKey: .latest),
                  events: try values.decodeIfPresent([Latest].self, forKey: .events) ?? [])
    }
}

/// Host-owned account/team scope and project catalog. Widget filters do not follow
/// the app's site selection. Cached summaries are bounded, and contain no credentials.
struct WidgetAccountContext: Codable, Equatable, Sendable {
    struct Project: Codable, Equatable, Sendable, Identifiable { var id: String; var name: String }
    static let allProjectsID = "__all_projects__"
    var schema = 1
    var revision: String
    var accountID: String
    var teamID: String?
    var source: WidgetDeploymentSnapshot.Source
    var projects: [Project]
    var cachedSnapshots: [WidgetDeploymentSnapshot]

    var isValid: Bool {
        schema == 1 && !revision.isEmpty && !accountID.isEmpty && projects.count <= 500
        && Set(projects.map(\.id)).count == projects.count
        && projects.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty }
        && cachedSnapshots.count <= projects.count + 1
        && cachedSnapshots.allSatisfy {
            $0.isValid && $0.revision == revision && $0.accountID == accountID && $0.teamID == teamID
            && $0.source == source && name(for: $0.projectID) != nil
        }
    }

    func name(for projectID: String) -> String? {
        projectID == Self.allProjectsID ? "All projects" : projects.first { $0.id == projectID }?.name
    }

    func seed(for projectID: String) -> WidgetDeploymentSnapshot? {
        guard let name = name(for: projectID) else { return nil }
        return cachedSnapshots.first { $0.projectID == projectID }
            ?? .make(projectID: projectID, projectName: name, accountID: accountID,
                     teamID: teamID, revision: revision, source: source, deployments: [])
    }

    func isSameScope(as other: Self) -> Bool {
        revision == other.revision && accountID == other.accountID && teamID == other.teamID && source == other.source
    }
}
