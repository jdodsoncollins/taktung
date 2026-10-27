import AppIntents
import Foundation

struct ProjectEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project")
    static let defaultQuery = ProjectQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ProjectQuery: EntityStringQuery {
    var store = WidgetSnapshotStore()
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        let projects = systemProjects(in: widgetAccountContext(store: store))
        return identifiers.compactMap { id in
            projects.first { $0.id == id }.map { ProjectEntity(id: $0.id, name: $0.name) }
        }
    }
    func entities(matching string: String) async throws -> [ProjectEntity] {
        systemProjects(in: widgetAccountContext(store: store), matching: string)
            .map { ProjectEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [ProjectEntity] { try await entities(matching: "") }
}

private func projectRoute(_ project: ProjectEntity?, action: ShortcutRoute.Action = .open) throws -> ShortcutRoute {
    guard let project else { return .init(section: .home, action: action) }
    guard let context = widgetAccountContext(), context.name(for: project.id) != nil,
          project.id != WidgetAccountContext.allProjectsID else { throw ShortcutFailure.unavailableProject }
    return .init(section: .home, action: action, projectID: project.id,
                 accountID: context.accountID, teamID: context.teamID)
}

struct GetDeploymentStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Deployment Status"
    static let description = IntentDescription("Returns the newest deployment and counts from the 20 most recent deployments in the connected workspace. Leave Project empty for all projects.")
    static var openAppWhenRun: Bool { false }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "Project") var project: ProjectEntity?
    static var parameterSummary: some ParameterSummary { Summary("Get deployment status for \(\.$project)") }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = try await ShortcutDeploymentStatus().read(projectID: project?.id)
        return .result(value: text, dialog: "\(text)")
    }
}

struct InspectProjectIntent: AppIntent {
    static let title: LocalizedStringResource = "Inspect Project"
    static let description = IntentDescription("Opens the selected project's production evidence in Taktung. Leave Project empty to use the current site.")
    static var openAppWhenRun: Bool { true }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "Project") var project: ProjectEntity?
    static var parameterSummary: some ParameterSummary { Summary("Inspect \(\.$project)") }

    @MainActor func perform() async throws -> some IntentResult {
        TaktRouter.shared.enqueue(try projectRoute(project))
        return .result()
    }
}

struct CheckSiteHealthIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Site Health"
    static let description = IntentDescription("Opens Taktung and explains the loaded project signals. Refreshes the chosen site's deployments; does not execute deployment actions.")
    static var openAppWhenRun: Bool { true }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "Project") var project: ProjectEntity?
    static var parameterSummary: some ParameterSummary { Summary("Check site health for \(\.$project)") }

    @MainActor func perform() async throws -> some IntentResult {
        TaktRouter.shared.enqueue(try projectRoute(project, action: .checkHealth))
        return .result()
    }
}

struct OpenHomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Home"
    static let description = IntentDescription("Opens Taktung on Home.")
    static var openAppWhenRun: Bool { true }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktRouter.open(.home)
        return .result()
    }
}

struct OpenDeploymentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Deployments"
    static let description = IntentDescription("Opens the deployment list.")
    static var openAppWhenRun: Bool { true }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktRouter.open(.deploys)
        return .result()
    }
}

struct OpenActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Field Log"
    static let description = IntentDescription("Opens the local record of checks, notes and comparisons.")
    static var openAppWhenRun: Bool { true }
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktRouter.open(.activity)
        return .result()
    }
}

struct TaktungShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDeploymentStatusIntent(),
            phrases: ["Check deploy status in \(.applicationName)", "Get deployment status with \(.applicationName)",
                      "Check \(\.$project) deploy status in \(.applicationName)"],
            shortTitle: "Deploy Status",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: InspectProjectIntent(),
            phrases: ["Inspect a project in \(.applicationName)", "Inspect \(\.$project) in \(.applicationName)"],
            shortTitle: "Inspect Project",
            systemImageName: "server.rack"
        )
        AppShortcut(
            intent: CheckSiteHealthIntent(),
            phrases: ["Check site health in \(.applicationName)", "Check \(\.$project) health in \(.applicationName)"],
            shortTitle: "Site Health",
            systemImageName: "stethoscope"
        )
        AppShortcut(
            intent: OpenHomeIntent(),
            phrases: ["Open \(.applicationName)", "Show \(.applicationName) home"],
            shortTitle: "Home",
            systemImageName: "house"
        )
        AppShortcut(
            intent: OpenDeploymentsIntent(),
            phrases: ["Show \(.applicationName) deployments", "Open deploys in \(.applicationName)"],
            shortTitle: "Deploys",
            systemImageName: "arrow.up.right"
        )
        AppShortcut(
            intent: OpenActivityIntent(),
            phrases: ["Show \(.applicationName) activity", "Open the field log in \(.applicationName)"],
            shortTitle: "Field Log",
            systemImageName: "clock"
        )
    }
}
