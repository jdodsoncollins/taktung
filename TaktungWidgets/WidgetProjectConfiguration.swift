import AppIntents

struct WidgetProjectEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Project")
    static let defaultQuery = WidgetProjectQuery()
    static let all = Self(id: WidgetAccountContext.allProjectsID, name: "All projects")
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WidgetProjectQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetProjectEntity] {
        let known = catalog()
        // Keep a removed project's identity; don't silently broaden its widget to All.
        return identifiers.map { id in known.first { $0.id == id } ?? .init(id: id, name: "Unavailable project") }
    }

    func suggestedEntities() async throws -> [WidgetProjectEntity] { catalog() }
    func defaultResult() async -> WidgetProjectEntity? { .all }

    private func catalog() -> [WidgetProjectEntity] {
        guard let context = widgetAccountContext() else { return [.all] }
        return [.all] + systemProjects(in: context)
            .map { WidgetProjectEntity(id: $0.id, name: $0.name) }
    }
}

struct DeploymentWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Deployment status"
    static let description = IntentDescription("Show all projects or a specific project in the current workspace.")
    @Parameter(title: "Project") var project: WidgetProjectEntity?
    static var parameterSummary: some ParameterSummary { Summary("Show \(\.$project)") }
    init() { project = .all }
}

