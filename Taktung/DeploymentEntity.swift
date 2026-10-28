import AppIntents
import CoreSpotlight
import Foundation

/// A recent deployment the person chose to show in Spotlight. Resolves only
/// from the device-only catalog written with the index; no request is made.
struct DeploymentEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Deployment")
    static let defaultQuery = DeploymentEntityQuery()

    var id: String
    var record: SpotlightDeployment

    init(_ record: SpotlightDeployment) {
        id = record.id
        self.record = record
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(record.title)", subtitle: "\(record.subtitle)", image: .init(systemName: symbol))
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.title = record.title
        attributes.contentDescription = record.subtitle
        attributes.contentCreationDate = record.createdAt
        attributes.keywords = [record.siteName, record.branch, record.shortSHA, record.state.rawValue.lowercased(),
                               record.target?.rawValue, "deployment", "deploy"].compactMap { $0 }
        return attributes
    }

    private var symbol: String {
        switch record.state {
        case .ready: "checkmark.circle"
        case .error, .blocked: "exclamationmark.triangle"
        case .canceled: "xmark.circle"
        default: "clock"
        }
    }
}

struct DeploymentEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DeploymentEntity] {
        let deployments = SpotlightCatalogStore.load()?.deployments ?? []
        return identifiers.compactMap { id in deployments.first { $0.id == id }.map(DeploymentEntity.init) }
    }

    func suggestedEntities() async throws -> [DeploymentEntity] {
        (SpotlightCatalogStore.load()?.deployments ?? []).prefix(10).map(DeploymentEntity.init)
    }
}

/// Opens a Spotlight deployment in its site's Deploys tab. Read-only: deployment
/// actions stay behind the app's own confirmation.
struct OpenDeploymentIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Deployment"
    static let description = IntentDescription("Opens a recent deployment shown in Spotlight.")
    static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
    @Parameter(title: "Deployment") var target: DeploymentEntity

    @MainActor func perform() async throws -> some IntentResult {
        TaktRouter.shared.enqueue(.init(section: .deploys, projectID: target.record.projectID,
                                        accountID: target.record.accountID, teamID: target.record.teamID,
                                        deploymentID: target.id))
        return .result()
    }
}
