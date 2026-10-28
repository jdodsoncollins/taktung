import Foundation
import CryptoKit

/// A recent deployment as Spotlight may show it: status, environment, branch,
/// short commit and commit subject. Never build logs, environment data or URLs.
struct SpotlightDeployment: Codable, Hashable, Sendable, Identifiable {
    var id: DeploymentID
    var accountID: String
    var teamID: TeamID?
    var projectID: ProjectID
    var siteName: String
    var title: String
    var state: DeploymentState
    var target: DeploymentTarget?
    var branch: String?
    var shortSHA: String?
    var createdAt: Date

    var subtitle: String {
        [siteName, state.rawValue.capitalized, target?.rawValue.capitalized, branch, shortSHA]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

/// One of the person's own Field Log notes, opted in for Spotlight.
struct SpotlightNote: Hashable, Sendable, Identifiable {
    var id: String
    var title: String
    var text: String
    var createdAt: Date
}

/// What Spotlight should hold now. Revisions are created in order on the main
/// actor, so the indexer can ignore a late, superseded state.
struct SpotlightState: Sendable {
    enum Deployments: Sendable {
        case remove
        case keep
        case replace(projectID: ProjectID, items: [SpotlightDeployment])
    }
    var revision: Int
    /// Nil removes everything Taktung has indexed.
    var scope: EvidenceScope?
    var deployments: Deployments
    /// Nil removes all notes.
    var notes: [SpotlightNote]?
}

enum SpotlightContent {
    static let deploymentsPerSite = 20
    static let maximumDeployments = 200
    static let maximumNotes = 200
    static let maximumNoteCharacters = 300
    static let noteDomain = "fieldlog-notes"

    /// The newest deployments for one site, reduced to secret-free metadata.
    static func deployments(_ list: [VercelDeploymentSummary], project: VercelProject, scope: EvidenceScope) -> [SpotlightDeployment] {
        guard !scope.isDemo else { return [] }
        let site = String(siteTitle(project).prefix(120))
        return list.sorted { $0.createdAt > $1.createdAt }.prefix(deploymentsPerSite).compactMap { d in
            let title = String(redactBuildLog(firstCommitLine(d.meta.githubCommitMessage, max: 120) ?? d.name).prefix(140))
            let branch = d.meta.githubCommitRef.map { String(redactBuildLog($0).prefix(100)) }
            guard !containsSecretLike(title), !containsSecretLike(branch ?? "") else { return nil }
            return SpotlightDeployment(id: d.id, accountID: scope.accountID, teamID: scope.teamID, projectID: project.id,
                                       siteName: site, title: title, state: d.state, target: d.target, branch: branch,
                                       shortSHA: d.meta.githubCommitSha.map { String($0.prefix(7)) },
                                       createdAt: Date(timeIntervalSince1970: d.createdAt / 1_000))
        }
    }

    /// Replaces one site's entries and keeps the rest of the same scope, newest first and bounded.
    static func merge(_ existing: [SpotlightDeployment], replacing projectID: ProjectID,
                      with items: [SpotlightDeployment], scope: EvidenceScope) -> [SpotlightDeployment] {
        let kept = existing.filter { $0.projectID != projectID && $0.accountID == scope.accountID && $0.teamID == scope.teamID }
        let fresh = items.filter { $0.accountID == scope.accountID && $0.teamID == scope.teamID }
        return Array((fresh + kept).sorted { $0.createdAt > $1.createdAt }.prefix(maximumDeployments))
    }

    /// Only the person's own notes; checks, comparisons and actions stay in the app.
    static func notes(_ activity: [ActivityItem], scope: EvidenceScope) -> [SpotlightNote] {
        guard !scope.isDemo else { return [] }
        return activity.filter { $0.fieldLogCategory == .notes }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(maximumNotes)
            .compactMap { item in
                let text = String(redactBuildLog(item.detail).prefix(maximumNoteCharacters))
                guard !text.isEmpty, !containsSecretLike(text) else { return nil }
                return SpotlightNote(id: noteIdentifier(itemID: item.id, scope: scope),
                                     title: "Field Log note · \(item.projectName ?? "Account")",
                                     text: text, createdAt: item.createdAt)
            }
    }

    static func noteIdentifier(itemID: String, scope: EvidenceScope) -> String {
        "note.\(scopeDigest(scope)).\(itemID)"
    }

    /// The Field Log record a Spotlight note opens, if it belongs to the current scope.
    static func noteItemID(_ identifier: String, scope: EvidenceScope?) -> String? {
        guard let scope else { return nil }
        let prefix = "note.\(scopeDigest(scope))."
        guard identifier.hasPrefix(prefix), identifier.count > prefix.count else { return nil }
        return String(identifier.dropFirst(prefix.count))
    }

    static func scopeDigest(_ scope: EvidenceScope) -> String {
        let value = scope.accountID + "\n" + (scope.teamID ?? "personal")
        return SHA256.hash(data: Data(value.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
