import Foundation

enum ShortcutFailure: LocalizedError {
    case connect, unavailableProject, workspaceChanged, unavailable
    var errorDescription: String? {
        switch self {
        case .connect: "Open Taktung and connect to Vercel, then try again."
        case .unavailableProject: "This project is unavailable in the current workspace. Choose another project."
        case .workspaceChanged: "The Vercel workspace changed. Run the shortcut again."
        case .unavailable: "Deployment status could not be refreshed. Open Taktung to check the last loaded data."
        }
    }
}

/// Shared widget mapping, one fresh read, no generated status and no deployment mutations.
struct ShortcutDeploymentStatus: Sendable {
    var store = WidgetSnapshotStore()
    var refresh: @Sendable (WidgetDeploymentSnapshot, String) async throws -> WidgetDeploymentSnapshot = {
        try await WidgetDeploymentService().refresh($0, token: $1)
    }

    func read(projectID: String?) async throws -> String {
        guard let token = store.token(), !token.isEmpty, let context = store.load(),
              context.source == .live else { throw ShortcutFailure.connect }
        let projectID = projectID ?? WidgetAccountContext.allProjectsID
        guard let seed = context.seed(for: projectID) else { throw ShortcutFailure.unavailableProject }
        let snapshot: WidgetDeploymentSnapshot
        do { snapshot = try await refresh(seed, token) }
        catch WidgetDeploymentService.Failure.unauthorized { throw ShortcutFailure.connect }
        catch is CancellationError { throw CancellationError() }
        catch { throw ShortcutFailure.unavailable }
        try Task.checkCancellation()
        guard let current = store.load(), current.isSameScope(as: context), store.token() == token,
              current.name(for: projectID) != nil else { throw ShortcutFailure.workspaceChanged }
        guard snapshot.isValid, snapshot.isSameScope(as: seed) else { throw ShortcutFailure.unavailable }
        store.saveCache(snapshot)
        return Self.summary(snapshot)
    }

    static func summary(_ snapshot: WidgetDeploymentSnapshot) -> String {
        let scope = safeName(snapshot.projectName)
        guard let latest = snapshot.latest else { return "No deployments were found for \(scope)." }
        let target = latest.target.map { " \($0.rawValue)" } ?? ""
        let project = snapshot.projectID == WidgetAccountContext.allProjectsID
            ? " for \(safeName(latest.projectName ?? "a project"))" : ""
        let date = latest.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "Latest\(target) deployment\(project): \(latest.state.rawValue.lowercased()), created \(date). "
            + "\(scope), most recent \(snapshot.total): \(snapshot.ready) ready, \(snapshot.failed) failed or canceled, "
            + "\(snapshot.building) building or queued."
    }

    private static func safeName(_ value: String) -> String {
        guard !containsSecretLike(value), redactBuildLog(value) == value else { return "the selected scope" }
        return String(value.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(120))
    }
}
