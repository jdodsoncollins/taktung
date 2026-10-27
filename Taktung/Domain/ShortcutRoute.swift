import Foundation
import Observation

enum TaktSection: String, Hashable, Sendable {
    case home, deploys, activity, search
}

struct ShortcutRoute: Identifiable, Equatable, Sendable {
    enum Action: Sendable { case open, checkHealth }
    var id = UUID()
    var section: TaktSection
    var action: Action = .open
    var projectID: String?
    var accountID: String?
    var teamID: String?

    func matches(accountID: String?, teamID: String?) -> Bool {
        self.accountID == nil || (self.accountID == accountID && self.teamID == teamID)
    }

    static func from(_ url: URL) -> Self? {
        guard url.scheme == AppConfig.urlScheme, let host = url.host,
              let section = TaktSection(rawValue: host) else { return nil }
        return Self(section: section)
    }
}

/// Retains an invocation until an active scene has finished connection restoration.
/// The queue is consumed once, so another scene cannot repeat an inspection.
@MainActor @Observable
final class TaktRouter {
    static let shared = TaktRouter()
    private(set) var pending: ShortcutRoute?

    func enqueue(_ route: ShortcutRoute) { pending = route }
    func takePending() -> ShortcutRoute? {
        defer { pending = nil }
        return pending
    }
    static func open(_ section: TaktSection) { shared.enqueue(.init(section: section)) }
}
