import Foundation
import AppIntents
import CoreSpotlight
import UniformTypeIdentifiers

/// The person's Spotlight choices. Both are off until they turn them on in Settings.
struct SpotlightSettings: Equatable, Sendable {
    static let deploymentsKey = "spotlight.recentDeployments"
    static let notesKey = "spotlight.fieldLogNotes"
    var deployments: Bool
    var notes: Bool

    static var current: SpotlightSettings {
        SpotlightSettings(deployments: UserDefaults.standard.bool(forKey: deploymentsKey),
                          notes: UserDefaults.standard.bool(forKey: notesKey))
    }
}

protocol SpotlightIndexing: Sendable {
    func apply(_ state: SpotlightState) async
}

/// The deployments currently in Spotlight, so a result can be opened again.
/// Secret-free metadata, device-only, excluded from backup and erased with the index.
enum SpotlightCatalogStore {
    struct Catalog: Codable, Equatable {
        var version = 1
        var scope: EvidenceScope
        var deployments: [SpotlightDeployment]
    }

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TaktungSpotlight", isDirectory: true)
            .appendingPathComponent("catalog.json")
    }

    static func load(from url: URL = defaultURL) -> Catalog? {
        guard let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data), catalog.version == 1 else { return nil }
        return catalog
    }

    static func save(_ catalog: Catalog, to url: URL = defaultURL) {
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                 attributes: [.protectionKey: FileProtectionType.complete])
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var protectedFolder = folder
        try? protectedFolder.setResourceValues(excluded)
        try? JSONEncoder().encode(catalog).write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func erase(at url: URL = defaultURL) {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Owns Taktung's Spotlight items. Applies only the newest state, so a late
/// update for an earlier account, team or preference cannot restore removed items.
actor SpotlightIndexer: SpotlightIndexing {
    static let shared = SpotlightIndexer()
    /// Nil uses the app's default index. CSSearchableIndex is not Sendable, so each call makes its own handle.
    private let indexName: String?
    private let catalogURL: URL
    private var lastRevision = Int.min
    /// Unknown at launch, so the first removal always runs.
    private var indexedNotes: [SpotlightNote]?
    private var cleanedThisLaunch = false

    init(indexName: String? = nil, catalogURL: URL = SpotlightCatalogStore.defaultURL) {
        self.indexName = indexName
        self.catalogURL = catalogURL
    }

    private nonisolated func index() -> CSSearchableIndex {
        indexName.map { CSSearchableIndex(name: $0) } ?? .default()
    }

    func apply(_ state: SpotlightState) async {
        guard state.revision > lastRevision else { return }
        lastRevision = state.revision
        guard let scope = state.scope, !scope.isDemo else {
            await removeAll()
            return
        }
        var catalog = SpotlightCatalogStore.load(from: catalogURL)
        if catalog?.scope != scope {
            if catalog != nil || !cleanedThisLaunch { await removeAll() }
            catalog = .init(scope: scope, deployments: [])
        }
        guard var current = catalog else { return }

        switch state.deployments {
        case .keep:
            break
        case .remove:
            if !current.deployments.isEmpty || !cleanedThisLaunch {
                try? await index().deleteAppEntities(ofType: DeploymentEntity.self)
            }
            current.deployments = []
        case .replace(let projectID, let items):
            let merged = SpotlightContent.merge(current.deployments, replacing: projectID, with: items, scope: scope)
            let removed = Set(current.deployments.map(\.id)).subtracting(merged.map(\.id))
            if !removed.isEmpty {
                try? await index().deleteAppEntities(identifiedBy: Array(removed), ofType: DeploymentEntity.self)
            }
            let changed = merged.filter { !current.deployments.contains($0) }
            if !changed.isEmpty { try? await index().indexAppEntities(changed.map(DeploymentEntity.init)) }
            current.deployments = merged
        }
        SpotlightCatalogStore.save(current, to: catalogURL)

        let notes = state.notes ?? []
        if indexedNotes != notes {
            try? await index().deleteSearchableItems(withDomainIdentifiers: [SpotlightContent.noteDomain])
            if !notes.isEmpty {
                let items = notes.map { note -> CSSearchableItem in
                    let attributes = CSSearchableItemAttributeSet(contentType: .text)
                    attributes.title = note.title
                    attributes.contentDescription = note.text
                    attributes.contentCreationDate = note.createdAt
                    return CSSearchableItem(uniqueIdentifier: note.id, domainIdentifier: SpotlightContent.noteDomain,
                                            attributeSet: attributes)
                }
                try? await index().indexSearchableItems(items)
            }
            indexedNotes = notes
        }
        cleanedThisLaunch = true
    }

    private func removeAll() async {
        guard !cleanedThisLaunch || indexedNotes?.isEmpty == false
                || FileManager.default.fileExists(atPath: catalogURL.path) else { return }
        try? await index().deleteAppEntities(ofType: DeploymentEntity.self)
        try? await index().deleteAllSearchableItems()
        SpotlightCatalogStore.erase(at: catalogURL)
        indexedNotes = []
        cleanedThisLaunch = true
    }
}
