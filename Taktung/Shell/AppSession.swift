import Foundation
import Observation
import WidgetKit
import AppIntents

enum ConnectionAttemptResult: Sendable {
    case connected(TokenSource)
    case rejected(String)
}

enum MutationMode: String, Sendable {
    case redeploy
    case promote
    case rollback
}

@MainActor
@Observable
final class AppSession {
    var connection: VercelConnection = .empty()
    var projects: [VercelProject] = []
    var selectedProjectId: ProjectID?
    var deployments: [VercelDeploymentSummary] = []
    var selectedDeployment: VercelDeploymentSummary?
    var recentActivity: [ActivityItem] = []
    private(set) var evidenceScope: EvidenceScope? {
        didSet { if oldValue != evidenceScope { recentSearches = [] } }
    }
    /// Deployments returned by Search for the selected site. Detail, inspection
    /// and confirmed actions accept them like loaded deployments until the scope changes.
    private(set) var searchedDeployments: [VercelDeploymentSummary] = []
    /// This launch's submitted searches for the current account, newest first. Memory only.
    private(set) var recentSearches: [String] = []
    /// A search to run once Search appears for a newly selected site.
    var pendingSearch: String?
    private(set) var historyStorageError: String?
    private(set) var historyIsBusy = false
    @ObservationIgnored let evidenceStore: LocalEvidenceStore
    @ObservationIgnored private var historyWriteTask: Task<Void, Never>?
    var opsNarrative: OpsNarrative?
    var envDrift: EnvDriftReport?
    var incident: IncidentSummary?
    private(set) var incidentDeploymentId: DeploymentID?
    var lastError: String?
    var isBusy = false
    var isRehydrating = true
    var onDeviceAvailable = false
    private(set) var isGeneratingBrief = false
    private(set) var reviewOpportunity: ReviewOpportunity?
    var allowsReviewRequests: Bool { !isDemoMode && connection.isConnected }
    var tokenSource: TokenSource?
    var pollingDeploymentId: DeploymentID?
    var pollProgress: Double?
    var settingsOpen = false
    var sitePickerOpen = false
    var pendingMutation: PendingMutation?

    struct PendingMutation: Identifiable {
        var id = UUID()
        var title: String
        var message: String
        var action: TaktAction
        var mode: MutationMode
    }

    var selectedProject: VercelProject? {
        projects.first { $0.id == selectedProjectId }
    }

    var showsSearch: Bool { onDeviceAvailable || isDemoMode }

    /// Loaded deployments plus Search results for the same site and scope.
    var knownDeployments: [VercelDeploymentSummary] {
        let loaded = Set(deployments.map(\.id))
        return deployments + searchedDeployments.filter { !loaded.contains($0.id) }
    }

    var canDiagnose: Bool { selectedProject != nil }

    var inspectionScope: InspectionScope? {
        guard connection.isConnected, let account = evidenceScope, let projectID = selectedProject?.id else { return nil }
        return InspectionScope(account: account, projectID: projectID, revision: scopeGeneration)
    }

    func inspectProject(_ tool: ProjectTool, scope: InspectionScope, deploymentID: DeploymentID? = nil) async throws -> InspectionResult {
        let api = try await inspectionAPI(scope: scope, deploymentID: deploymentID)
        let result = try await api.inspect(tool, projectID: scope.projectID, teamID: connection.selectedTeamId, deploymentID: deploymentID)
        try Task.checkCancellation()
        guard inspectionScope == scope else { throw CancellationError() }
        if tool == .domains {
            domainSignals = (scope, result.fetchedAt, result.rows.filter { $0.tone == .warning }.count)
        }
        return result
    }

    func recordRuntimeSample(scope: InspectionScope, deploymentID: DeploymentID, records: Int, errors: Int) {
        guard inspectionScope == scope, records > 0 else { return }
        runtimeSignals = (scope, Date(), deploymentID, min(records, 500), min(errors, 500))
    }

    func loadAnalytics(scope: InspectionScope, window: AnalyticsWindow) async throws -> AnalyticsOverview {
        let api = try await inspectionAPI(scope: scope, deploymentID: nil)
        let team = connection.selectedTeamId
        let result = try await api.analyticsOverview(projectID: scope.projectID, teamID: team, window: window)
        try Task.checkCancellation()
        guard inspectionScope == scope else { throw CancellationError() }
        return result
    }

    func loadAnalyticsSegments(scope: InspectionScope, dimension: AnalyticsDimension, window: AnalyticsWindow) async throws -> [AnalyticsSegment] {
        let api = try await inspectionAPI(scope: scope, deploymentID: nil)
        let result = try await api.analyticsSegments(projectID: scope.projectID, teamID: connection.selectedTeamId, dimension: dimension, window: window)
        try Task.checkCancellation()
        guard inspectionScope == scope else { throw CancellationError() }
        return result
    }

    func runtimeLogStream(scope: InspectionScope, deploymentID: DeploymentID) async throws -> AsyncThrowingStream<RuntimeLogEntry, Error> {
        let api = try await inspectionAPI(scope: scope, deploymentID: deploymentID)
        return api.runtimeLogs(projectID: scope.projectID, teamID: connection.selectedTeamId, deploymentID: deploymentID)
    }

    private func inspectionAPI(scope: InspectionScope, deploymentID: DeploymentID?) async throws -> any VercelAPIClient {
        guard inspectionScope == scope else { throw CancellationError() }
        if let deploymentID {
            guard knownDeployments.contains(where: { $0.id == deploymentID }) || selectedProject?.productionDeployment?.id == deploymentID else {
                throw VercelAPIError(status: 404, detail: "Deployment is no longer in this project's snapshot.")
            }
        }
        let api = try await ensureAPI()
        try Task.checkCancellation()
        guard inspectionScope == scope else { throw CancellationError() }
        return api
    }

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let clientFactory: (String) -> any VercelAPIClient
    @ObservationIgnored private let modelAvailability: () -> Bool
    @ObservationIgnored private let briefGenerator: @Sendable (String) async -> String?
    @ObservationIgnored private let searchPlanner: @Sendable (String, [String]) async -> SearchModelDraft?
    // On-device context (see the section at the end of this class).
    @ObservationIgnored private let fieldLogPlanner: @Sendable (String, [String]) async -> FieldLogModelDraft?
    @ObservationIgnored private let buildExplainer: @Sendable (BuildFailureExcerpt) async -> String?
    @ObservationIgnored private var buildExplanationTask: Task<Void, Never>?
    /// Key log lines, and an optional on-device sentence, for the last diagnosed failure. Memory only.
    private(set) var buildFailure: BuildFailureEvidence?
    @ObservationIgnored private let fieldLogSummarizer: @Sendable (String) async -> String?
    @ObservationIgnored private var digestTask: Task<Void, Never>?
    /// The last seven days of the Field Log, counted, with an optional on-device summary. Memory only.
    private(set) var fieldLogDigest: FieldLogDigest?
    @ObservationIgnored private var briefTask: Task<String?, Never>?
    @ObservationIgnored private var briefRequestID: UUID?
    @ObservationIgnored private var briefRequestKey: BriefReuseCache.Key?
    @ObservationIgnored private var briefCache = BriefReuseCache()
    @ObservationIgnored private var shortcutRouteID: UUID?
    private var client: (any VercelAPIClient)?
    private var pollTask: Task<Void, Never>?
    private var generation = 0
    private var hasBootstrapped = false
    @ObservationIgnored private let isDemoMode: Bool
    private var scopeGeneration = 0 {
        didSet { domainSignals = nil; runtimeSignals = nil; searchedDeployments = []; clearOnDeviceContext() }
    }
    @ObservationIgnored private var domainSignals: (scope: InspectionScope, date: Date, unverified: Int)?
    @ObservationIgnored private var runtimeSignals: (scope: InspectionScope, date: Date, deploymentID: String, records: Int, errors: Int)?
    private var deploymentSelection: DeploymentID?
    @ObservationIgnored private var widgetRevision = UUID().uuidString

    init(evidenceStore: LocalEvidenceStore = LocalEvidenceStore(), demoMode: Bool = DemoMode.isEnabled, keychain: KeychainStore = KeychainStore(),
         modelAvailability: @escaping () -> Bool = { OnDevicePlanner.isAvailable },
         briefGenerator: @escaping @Sendable (String) async -> String? = { await OnDevicePlanner.brief(context: $0) },
         searchPlanner: @escaping @Sendable (String, [String]) async -> SearchModelDraft? = { await OnDevicePlanner.planSearch(query: $0, siteNames: $1) },
         fieldLogPlanner: @escaping @Sendable (String, [String]) async -> FieldLogModelDraft? = { await OnDevicePlanner.planFieldLogSearch(query: $0, siteNames: $1) },
         buildExplainer: @escaping @Sendable (BuildFailureExcerpt) async -> String? = { await OnDevicePlanner.explainBuildFailure($0) },
         fieldLogSummarizer: @escaping @Sendable (String) async -> String? = { await OnDevicePlanner.summarizeFieldLog(prompt: $0) },
         clientFactory: @escaping (String) -> any VercelAPIClient = { token in LiveVercelAPIClient(tokenProvider: { token }) }) {
        self.evidenceStore = evidenceStore
        self.isDemoMode = demoMode
        self.keychain = keychain
        self.clientFactory = clientFactory
        self.modelAvailability = modelAvailability
        self.briefGenerator = briefGenerator
        self.searchPlanner = searchPlanner
        self.fieldLogPlanner = fieldLogPlanner
        self.buildExplainer = buildExplainer
        self.fieldLogSummarizer = fieldLogSummarizer
    }

    var hasLocalAccountData: Bool { evidenceScope != nil || tokenSource != nil || connection.user != nil }

    func refreshModelAvailability() {
        onDeviceAvailable = modelAvailability()
        if !onDeviceAvailable { cancelBriefGeneration(clearCache: true) }
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        isRehydrating = true
        refreshModelAvailability()
        defer { isRehydrating = false }

        if isDemoMode {
            await loadDemo()
            return
        }

        // Keep the last authenticated account's history readable during an API outage.
        if keychain.load(KeychainStore.Key.accessToken) != nil,
           let accountID = keychain.load(KeychainStore.Key.evidenceUserID) {
            await restoreHistory(scope: EvidenceScope(accountID: accountID,
                                                       teamID: keychain.selectedTeamID()))
        }

        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["TAKT_UI_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !token.isEmpty
        {
            _ = await connectWithToken(token)
            return
        }
        #endif

        if let token = keychain.load(KeychainStore.Key.accessToken), !token.isEmpty {
            let sourceRaw = keychain.load(KeychainStore.Key.tokenSource)
            tokenSource = sourceRaw.flatMap(TokenSource.init(rawValue:)) ?? .pat
            _ = await connectWithStoredToken(token)
        } else {
            invalidateWidget()
        }
    }

    func connectWithToken(_ raw: String) async -> ConnectionAttemptResult {
        if isDemoMode {
            return .rejected("Demo mode is on. Live Vercel is disabled.")
        }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return .rejected("Personal access token is required.")
        }
        generation += 1
        let gen = generation
        isBusy = true
        lastError = nil
        if !connection.isConnected { connection.status = .connecting }
        defer { if gen == generation { isBusy = false } }
        do {
            let live = clientFactory(token)
            let user = try await live.getUser()
            let teams = try await live.listTeams()
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            try await finishConnect(api: live, token: token, user: user, teams: teams, detail: "Signed in with personal access token", generation: gen)
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            return .connected(.pat)
        } catch {
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            if !connection.isConnected { connection.status = .error }
            connection.errorMessage = error.localizedDescription
            lastError = error.localizedDescription
            return .rejected(error.localizedDescription)
        }
    }

    func disconnect() async {
        reviewOpportunity = nil
        cancelBriefGeneration(clearCache: true)
        let oldScope = evidenceScope
        invalidateWidget()
        // Invalidate in-flight work before awaiting disk I/O; it must not recreate erased evidence.
        generation += 1
        scopeGeneration += 1
        evidenceScope = nil
        historyIsBusy = true
        pendingMutation = nil
        pollTask?.cancel()
        pollingDeploymentId = nil
        pollProgress = nil
        defer { historyIsBusy = false }
        isBusy = false
        await flushHistory()
        if let oldScope {
            do { try await evidenceStore.eraseAccount(scope: oldScope) }
            catch {
                evidenceScope = oldScope
                historyStorageError = "Local evidence could not be erased. Please try disconnecting again."
                lastError = historyStorageError
                return
            }
        }
        client = nil
        keychain.eraseAll()
        connection = .empty()
        projects = []
        selectedProjectId = nil
        deployments = []
        selectedDeployment = nil
        recentActivity = []
        evidenceScope = nil
        opsNarrative = nil
        envDrift = nil
        incident = nil
        tokenSource = nil
        lastError = nil
    }

    func selectTeam(_ teamId: TeamID?) async {
        guard !isDemoMode else { return }
        reviewOpportunity = nil
        cancelBriefGeneration(clearCache: true)
        invalidateWidget()
        scopeGeneration += 1
        let selectionGeneration = scopeGeneration
        pollTask?.cancel()
        pollingDeploymentId = nil
        pollProgress = nil
        pendingMutation = nil
        selectedProjectId = nil
        deployments = []
        selectedDeployment = nil
        opsNarrative = nil
        envDrift = nil
        incident = nil
        incidentDeploymentId = nil
        connection.selectedTeamId = teamId
        if let user = connection.user {
            await restoreHistory(scope: EvidenceScope(accountID: user.id, teamID: teamId))
        }
        guard scopeGeneration == selectionGeneration, connection.selectedTeamId == teamId else { return }
        try? keychain.saveTeamSelection(teamId)
        await refreshProjects()
    }

    func refreshProjects(loadSelectedDeployments: Bool = true) async {
        guard let api = try? await ensureAPI() else { return }
        let scope = scopeGeneration
        let teamId = connection.selectedTeamId
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            let list = try await api.listProjects(teamId: teamId)
            guard scope == scopeGeneration, teamId == connection.selectedTeamId else { return }
            projects = list
            publishWidgetSnapshot()
            appendActivity(
                kind: .refreshProjects,
                title: "Loaded projects",
                detail: "\(list.count) project(s) (list without N+1 deploy fan-out)",
                outcome: .success
            )
            if let selectedProjectId, list.contains(where: { $0.id == selectedProjectId }) {
                if loadSelectedDeployments { await loadDeployments(selectedProjectId) }
            } else if selectedProjectId != nil {
                await selectProject(nil)
            }
        } catch {
            guard scope == scopeGeneration, teamId == connection.selectedTeamId else { return }
            lastError = error.localizedDescription
        }
    }

    func selectProject(_ id: ProjectID?) async {
        reviewOpportunity = nil
        cancelBriefGeneration()
        scopeGeneration += 1
        pendingMutation = nil
        deploymentSelection = nil
        deployments = []
        selectedProjectId = id
        selectedDeployment = nil
        opsNarrative = nil
        envDrift = nil
        incident = nil
        incidentDeploymentId = nil
        if isDemoMode {
            if let id {
                deployments = buildDemoDeployments(projectId: id)
            } else {
                deployments = []
            }
            publishWidgetSnapshot()
            return
        }
        if let id {
            try? keychain.save(id, key: KeychainStore.Key.selectedProjectId)
            await loadDeployments(id)
        } else {
            keychain.delete(KeychainStore.Key.selectedProjectId)
            deployments = []
        }
    }

    func loadDeployments(_ projectId: ProjectID) async {
        guard let api = try? await ensureAPI() else { return }
        let scope = scopeGeneration
        let teamId = connection.selectedTeamId
        do {
            let list = try await api.listDeployments(projectId: projectId, teamId: teamId, limit: 30)
            guard scope == scopeGeneration, selectedProjectId == projectId else { return }
            deployments = list
            publishWidgetSnapshot()
            appendActivity(
                kind: .loadDeployments,
                title: "Loaded deployments",
                detail: "\(list.count) deployment(s)",
                outcome: .success,
                projectId: projectId
            )
        } catch {
            guard scope == scopeGeneration, selectedProjectId == projectId else { return }
            lastError = error.localizedDescription
        }
    }

    func selectDeployment(_ id: DeploymentID?) async {
        deploymentSelection = id
        let scope = scopeGeneration
        if selectedDeployment?.id != id {
            incident = nil
            incidentDeploymentId = nil
        }
        guard let id else {
            selectedDeployment = nil
            return
        }
        if let existing = knownDeployments.first(where: { $0.id == id }) {
            selectedDeployment = existing
        }
        guard let api = try? await ensureAPI() else { return }
        do {
            let loaded = try await api.getDeployment(id: id, teamId: connection.selectedTeamId)
            guard scope == scopeGeneration, deploymentSelection == id,
                  sourceDeploymentBelongsToProject(id, projectDeployments: knownDeployments) else { return }
            selectedDeployment = loaded
        } catch {
            guard scope == scopeGeneration, deploymentSelection == id else { return }
            lastError = error.localizedDescription
        }
    }

    func runOpsBrief() async {
        guard let project = selectedProject, !Task.isCancelled else { return }
        refreshModelAvailability()
        let scope = scopeGeneration
        let domain = domainSignals.flatMap { $0.scope == inspectionScope && (0..<300).contains(Date().timeIntervalSince($0.date)) ? $0 : nil }
        let runtime = runtimeSignals.flatMap { $0.scope == inspectionScope && (0..<300).contains(Date().timeIntervalSince($0.date)) ? $0 : nil }
        let ctx = BoundedOpsContext.build(
            projectName: siteTitle(project),
            productionState: project.productionDeployment?.state.rawValue,
            needsAttention: project.needsAttention,
            attentionReason: project.attentionReason.rawValue,
            incidentHeadline: incident?.headline,
            incidentCause: incident?.likelyCause,
            incidentConfidence: incident?.confidence.rawValue,
            envDriftCritical: envDrift?.findings.filter { $0.severity == .critical }.count ?? 0,
            envDriftSummary: envDrift?.summary,
            runtimeErrorCount: runtime?.errors,
            runtimeSummary: runtime.map { "A bounded sample of \($0.records) records from deployment \(String($0.deploymentID.prefix(16))). This is not a site-wide or hourly error total." },
            domainCritical: domain?.unverified ?? 0,
            domainSummary: domain == nil ? nil : "Ownership records were fetched within five minutes. DNS, TLS and uptime were not tested.",
            polling: pollingDeploymentId != nil
        )
        var narrative = synthesizeOpsNarrative(ctx)
        guard let prompt = BriefModelPolicy.prompt(narrative.body) else {
            lastError = "Brief contained secret-like text and was discarded."
            return
        }
        let key = BriefReuseCache.Key(accountID: connection.user?.id ?? "", teamID: connection.selectedTeamId,
                                      projectID: project.id, prompt: prompt)
        if isGeneratingBrief, briefRequestKey == key { return }
        cancelBriefGeneration()
        // Publish useful deterministic evidence immediately; generation is optional.
        opsNarrative = narrative
        appendActivity(kind: .note, title: "Diagnose", detail: narrative.headline,
                       outcome: .success, projectId: project.id)
        if !isDemoMode, onDeviceAvailable {
            if let sentence = briefCache.text(for: key) {
                narrative.body = sentence
                narrative.source = .appleFoundation
                opsNarrative = narrative
                recordReviewOpportunity(projectID: project.id, mayPrompt: true)
                return
            }
            let requestID = UUID()
            briefRequestID = requestID
            briefRequestKey = key
            isGeneratingBrief = true
            let evidence = narrative.body
            let generator = briefGenerator
            let task = Task { await generator(evidence) }
            briefTask = task
            let response = await task.value
            guard briefRequestID == requestID, scope == scopeGeneration,
                  selectedProjectId == project.id else { return }
            briefTask = nil
            briefRequestID = nil
            briefRequestKey = nil
            isGeneratingBrief = false
            guard !Task.isCancelled, !task.isCancelled else { return }
            if let response, let sentence = BriefModelPolicy.accept(response, requiresSampleQualifier: (runtime?.errors ?? 0) > 0,
                                                                   requiresOwnershipQualifier: (domain?.unverified ?? 0) > 0) {
                briefCache.insert(sentence, for: key)
                narrative = OpsNarrative(
                    headline: narrative.headline,
                    body: sentence,
                    nextSteps: narrative.nextSteps,
                    confidence: narrative.confidence,
                    usedFields: narrative.usedFields,
                    source: .appleFoundation
                )
            }
        }
        guard scope == scopeGeneration, selectedProjectId == project.id else { return }
        opsNarrative = narrative
        recordReviewOpportunity(projectID: project.id, mayPrompt: true)
    }

    private func recordReviewOpportunity(projectID: ProjectID, mayPrompt: Bool) {
        guard allowsReviewRequests, let scope = evidenceScope else { return }
        reviewOpportunity = .init(projectID: projectID, scope: scope, mayPrompt: mayPrompt)
    }

    private func cancelBriefGeneration(clearCache: Bool = false) {
        briefTask?.cancel()
        briefTask = nil
        briefRequestID = nil
        briefRequestKey = nil
        isGeneratingBrief = false
        if clearCache { briefCache.clear() }
    }

    func handleShortcutRoute(_ route: ShortcutRoute) async {
        shortcutRouteID = route.id
        guard route.matches(accountID: connection.user?.id, teamID: connection.selectedTeamId) else {
            lastError = ShortcutFailure.workspaceChanged.localizedDescription
            return
        }
        // A system handoff must reveal its destination and abandon any unconfirmed plan.
        settingsOpen = false
        sitePickerOpen = false
        pendingMutation = nil
        guard route.projectID != nil || route.action == .checkHealth else { return }
        guard connection.isConnected else {
            lastError = ShortcutFailure.connect.localizedDescription
            settingsOpen = true
            return
        }
        let originalScope = scopeGeneration
        if route.action == .checkHealth {
            // Fresh project evidence plus one selected-site deployment request; no fan-out.
            await refreshProjects(loadSelectedDeployments: false)
            guard shortcutRouteID == route.id, originalScope == scopeGeneration else { return }
        }
        guard let projectID = route.projectID ?? selectedProjectId else {
            sitePickerOpen = true
            return
        }
        guard projects.contains(where: { $0.id == projectID }) else {
            lastError = ShortcutFailure.unavailableProject.localizedDescription
            return
        }
        let expectedScope = scopeGeneration + (selectedProjectId == projectID ? 0 : 1)
        if selectedProjectId != projectID { await selectProject(projectID) }
        else if route.action == .checkHealth { await loadDeployments(projectID) }
        guard shortcutRouteID == route.id, scopeGeneration == expectedScope,
              selectedProjectId == projectID,
              route.matches(accountID: connection.user?.id, teamID: connection.selectedTeamId) else { return }
        if route.action == .checkHealth { await runOpsBrief() }
    }

    /// Rules first; Apple Intelligence reads only requests the rules cannot place.
    func interpretSearch(_ text: String) async -> SiteSearchInterpretation {
        let rules = planSiteSearch(text, projects: projects, selectedProjectID: selectedProjectId)
        guard rules.needsModel, !isDemoMode else { return rules }
        refreshModelAvailability()
        guard onDeviceAvailable else { return rules }
        let scope = scopeGeneration
        let draft = await searchPlanner(text, projects.map(siteTitle))
        guard !Task.isCancelled, scope == scopeGeneration else { return rules }
        guard let draft, let plan = SearchModelPolicy.plan(draft, query: text, rules: rules, projects: projects,
                                                           selectedProjectID: selectedProjectId) else { return rules }
        return SiteSearchInterpretation(plan: plan, interpreter: .appleIntelligence)
    }

    /// A live, read-only `GET /v7/deployments` for the selected site.
    func searchDeployments(_ query: DeploymentQuery) async throws -> [VercelDeploymentSummary] {
        guard let projectID = selectedProjectId else { throw CancellationError() }
        let scope = scopeGeneration
        let teamID = connection.selectedTeamId
        let api = try await ensureAPI()
        let found = try await api.searchDeployments(projectId: projectID, teamId: teamID, query: query)
        try Task.checkCancellation()
        guard scope == scopeGeneration, selectedProjectId == projectID, connection.selectedTeamId == teamID else {
            throw CancellationError()
        }
        let foundIDs = Set(found.map(\.id))
        searchedDeployments = Array((found + searchedDeployments.filter { !foundIDs.contains($0.id) }).prefix(300))
        return found
    }

    func rememberSearch(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !containsSecretLike(trimmed) else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        recentSearches = Array(recentSearches.prefix(5))
    }

    func clearRecentSearches() { recentSearches = [] }

    func runEnvDrift() async {
        guard let project = selectedProject, let api = try? await ensureAPI() else { return }
        let scope = scopeGeneration
        isBusy = true
        defer { isBusy = false }
        do {
            let meta = try await api.listEnvVarMeta(projectId: project.id, teamId: connection.selectedTeamId)
            guard scope == scopeGeneration, selectedProjectId == project.id else { return }
            envDrift = analyzeEnvDrift(meta)
            appendActivity(
                kind: .envDrift,
                title: "Env drift",
                detail: envDrift?.summary ?? "Checked env names only",
                outcome: .success,
                projectId: project.id
            )
        } catch {
            guard scope == scopeGeneration, selectedProjectId == project.id else { return }
            lastError = error.localizedDescription
        }
    }

    func loadBuildLogs(for id: DeploymentID) async throws -> [BuildLogLine] {
        let scope = scopeGeneration
        let projectID = selectedProjectId
        let teamID = connection.selectedTeamId
        let api = try await ensureAPI()
        guard scope == scopeGeneration else { throw CancellationError() }
        do {
            let lines = try await api.getBuildLogLines(id: id, teamId: teamID, limit: 500)
            try Task.checkCancellation()
            guard scope == scopeGeneration else { throw CancellationError() }
            appendActivity(
                kind: .loadLogs,
                title: "Loaded build logs",
                detail: "\(lines.count) line(s)",
                outcome: .success,
                projectId: projectID,
                deploymentId: id
            )
            return lines
        } catch {
            guard scope == scopeGeneration else { throw CancellationError() }
            lastError = error.localizedDescription
            throw error
        }
    }

    func runIncidentSummary() async {
        guard let project = selectedProject else { return }
        let scope = scopeGeneration
        let selectionAtStart = selectedDeployment?.id
        let failed =
            selectedDeployment.flatMap { isFailedState($0.state) ? $0 : nil }
            ?? project.latestFailedDeployment
            ?? deployments.first { isFailedState($0.state) }
        guard let failed else {
            lastError = "No failed deployment to diagnose."
            return
        }
        guard let api = try? await ensureAPI() else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let logs = try await api.getBuildLogLines(id: failed.id, teamId: connection.selectedTeamId, limit: 200)
            guard scope == scopeGeneration, selectedProjectId == project.id, selectedDeployment?.id == selectionAtStart else { return }
            let driftKeys = envDrift?.findings.filter { $0.kind == .missingInProduction }.map(\.key) ?? []
            incident = summarizeFailedDeployment(
                failed: failed,
                lastSuccess: project.lastSuccessfulDeployment,
                logLines: logs,
                missingProductionEnvKeys: driftKeys
            )
            incidentDeploymentId = failed.id
            appendActivity(
                kind: .incidentSummary,
                title: incident?.headline ?? "Incident",
                detail: incident?.likelyCause ?? "See evidence",
                outcome: .info,
                projectId: project.id,
                deploymentId: failed.id
            )
            recordBuildFailure(deploymentID: failed.id, logs: logs)
        } catch {
            guard scope == scopeGeneration, selectedProjectId == project.id else { return }
            lastError = error.localizedDescription
        }
    }

    func deploymentForDisplay(_ summary: VercelDeploymentSummary) -> VercelDeploymentSummary {
        if let current = selectedDeployment, current.id == summary.id,
           sourceDeploymentBelongsToProject(current.id, projectDeployments: knownDeployments) { return current }
        return summary
    }

    func requestMutation(mode: MutationMode, expectedDeploymentID: DeploymentID? = nil) {
        if let expectedDeploymentID, selectedDeployment?.id != expectedDeploymentID {
            pendingMutation = nil
            lastError = "The deployment selection changed. Open the deployment again before confirming an action."
            return
        }
        guard let project = selectedProject, let deploy = selectedDeployment ?? project.productionDeployment else {
            lastError = "Pick a deployment first."
            return
        }
        guard sourceDeploymentBelongsToProject(deploy.id, projectDeployments: knownDeployments) else {
            lastError = "The deployment does not belong to the selected site. Refresh and try again."
            return
        }
        let action: TaktAction
        switch mode {
        case .redeploy:
            action = .redeploy(
                deploymentId: deploy.id,
                projectId: project.id,
                teamId: connection.selectedTeamId,
                target: deploy.target
            )
        case .promote:
            action = .promoteToProduction(
                deploymentId: deploy.id,
                projectId: project.id,
                teamId: connection.selectedTeamId
            )
        case .rollback:
            action = .rollbackProduction(
                deploymentId: deploy.id,
                projectId: project.id,
                teamId: connection.selectedTeamId
            )
        }
        let descriptor = ConfirmationPolicy.shared.descriptor(for: action)
        guard let confirmation = mutationConfirmation(for: action) else { return }
        pendingMutation = PendingMutation(
            title: descriptor.title,
            message: formatMutationConfirmation(confirmation),
            action: action,
            mode: mode
        )
    }

    func confirmPendingMutation() async {
        guard let pending = pendingMutation else { return }
        pendingMutation = nil
        await confirmMutation(pending)
    }

    func confirmMutation(_ pending: PendingMutation) async {
        guard let project = selectedProject,
              pending.action.projectId == project.id,
              pending.action.deploymentId.map({ sourceDeploymentBelongsToProject($0, projectDeployments: knownDeployments) }) == true,
              mutationConfirmation(for: pending.action)?.teamId == connection.selectedTeamId else {
            lastError = "Confirmation did not match the planned mutation."
            return
        }
        if isDemoMode {
            lastError = "Demo mode cannot mutate deployments."
            appendActivity(
                kind: .redeploy,
                title: pending.title,
                detail: "Demo mode cannot mutate deployments.",
                outcome: .failure,
                projectId: pending.action.projectId,
                deploymentId: pending.action.deploymentId
            )
            return
        }
        guard let api = try? await ensureAPI() else { return }
        let connectionGeneration = generation
        let evidenceAtStart = evidenceScope
        let payload: (DeploymentID, ProjectID, TeamID?, DeploymentTarget?)
        switch pending.action {
        case .redeploy(let deploymentId, let projectId, let teamId, let target):
            payload = (deploymentId, projectId, teamId, target)
        case .promoteToProduction(let deploymentId, let projectId, let teamId):
            payload = (deploymentId, projectId, teamId, .production)
        case .rollbackProduction(let deploymentId, let projectId, let teamId):
            payload = (deploymentId, projectId, teamId, .production)
        default:
            return
        }
        let (deploymentId, projectId, teamId, target) = payload
        isBusy = true
        defer { isBusy = false }
        do {
            let acceptedId: DeploymentID
            switch pending.mode {
            case .redeploy:
                acceptedId = try await api.redeploy(deploymentId: deploymentId, projectId: projectId,
                                                     teamId: teamId, target: target).id
            case .promote:
                try await api.promote(deploymentId: deploymentId, projectId: projectId, teamId: teamId)
                acceptedId = deploymentId
            case .rollback:
                try await api.rollback(deploymentId: deploymentId, projectId: projectId, teamId: teamId)
                acceptedId = deploymentId
            }
            guard generation == connectionGeneration, evidenceScope == evidenceAtStart,
                  connection.selectedTeamId == teamId else { return }
            appendActivity(
                kind: pending.mode == .rollback ? .rollback : pending.mode == .promote ? .promote : .redeploy,
                title: pending.title,
                detail: "Accepted \(acceptedId). Polling for READY.",
                outcome: .info,
                projectId: projectId,
                deploymentId: acceptedId
            )
            await pollUntilReady(acceptedId, projectId: projectId, teamId: teamId, verifyProduction: pending.mode != .redeploy)
        } catch {
            guard generation == connectionGeneration, evidenceScope == evidenceAtStart else { return }
            lastError = error.localizedDescription
            appendActivity(
                kind: .redeploy,
                title: pending.title,
                detail: error.localizedDescription,
                outcome: .failure,
                projectId: projectId,
                deploymentId: deploymentId
            )
        }
    }

    func clearActivity(expectedScope: EvidenceScope? = nil) async {
        guard let scope = evidenceScope, expectedScope == nil || expectedScope == scope else { return }
        historyStorageError = nil
        historyIsBusy = true
        defer { historyIsBusy = false }
        let beforeClear = recentActivity
        recentActivity = []
        let previous = historyWriteTask
        let store = evidenceStore
        historyWriteTask = Task { [weak self] in
            await previous?.value
            do { try await store.replaceHistory([], scope: scope) }
            catch {
                if let self, self.evidenceScope == scope {
                    let newIDs = Set(self.recentActivity.map(\.id))
                    self.recentActivity += beforeClear.filter { !newIDs.contains($0.id) }
                    self.recentActivity.sort { $0.createdAt > $1.createdAt }
                    self.recentActivity = Array(self.recentActivity.prefix(LocalEvidenceStore.historyLimit))
                    self.historyStorageError = "History could not be cleared. Existing records have been kept. Try again."
                }
            }
        }
        await historyWriteTask?.value
    }

    func addHistoryNote(_ text: String, scope: EvidenceScope, projectID: ProjectID?, deploymentID: DeploymentID?, noteID: String? = nil) async -> Bool {
        guard evidenceScope == scope, selectedProjectId == projectID else { return false }
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return false }
        appendActivity(kind: .note, title: "Note", detail: note, outcome: .info,
                       projectId: projectID, deploymentId: deploymentID, id: noteID)
        await flushHistory()
        return evidenceScope == scope && historyStorageError == nil
    }

    func recordComparison(title: String, detail: String, projectID: ProjectID, deploymentID: DeploymentID, scope: EvidenceScope) async {
        guard evidenceScope == scope, selectedProjectId == projectID else { return }
        appendActivity(kind: .deploymentCompare, title: title, detail: detail, outcome: .success,
                       projectId: projectID, deploymentId: deploymentID)
        await flushHistory()
        if evidenceScope == scope, selectedProjectId == projectID, historyStorageError == nil {
            // Count meaningful comparison use, but never interrupt its active review sheet.
            recordReviewOpportunity(projectID: projectID, mayPrompt: false)
        }
    }

    func flushHistory() async {
        await historyWriteTask?.value
    }

    func restoreHistory(scope: EvidenceScope) async {
        evidenceScope = scope
        recentActivity = []
        historyStorageError = nil
        await flushHistory()
        guard evidenceScope == scope else { return }
        do {
            let restored = try await evidenceStore.loadHistory(scope: scope)
            guard evidenceScope == scope else { return }
            recentActivity = restored ?? []
        } catch {
            guard evidenceScope == scope else { return }
            historyStorageError = error.localizedDescription
        }
    }

    private func pollUntilReady(_ id: DeploymentID, projectId: ProjectID, teamId: TeamID?, verifyProduction: Bool) async {
        pollTask?.cancel()
        let connectionGeneration = generation
        pollingDeploymentId = id
        pollProgress = 0
        let api: any VercelAPIClient
        do { api = try await ensureAPI() } catch { pollingDeploymentId = nil; return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await pollDeploymentUntilTerminal(
                    getState: {
                        let d = try await api.getDeployment(id: id, teamId: teamId)
                        try Task.checkCancellation()
                        if verifyProduction, d.state == .ready,
                           try await api.productionDeploymentID(projectId: projectId, teamId: teamId) != id {
                            return .building
                        }
                        return d.state
                    }
                )
                guard !Task.isCancelled, self.generation == connectionGeneration,
                      self.connection.selectedTeamId == teamId else { return }
                await MainActor.run {
                    self.pollingDeploymentId = nil
                    self.pollProgress = nil
                    self.appendActivity(
                        kind: .deploymentPoll,
                        title: result.isReady ? "Deployment READY" : "Deploy poll finished",
                        detail: result.summary,
                        outcome: result.isReady ? .success : .failure,
                        projectId: projectId,
                        deploymentId: id
                    )
                }
                if self.selectedProjectId == projectId {
                    await self.loadDeployments(projectId)
                }
            } catch {
                guard !Task.isCancelled, self.generation == connectionGeneration,
                      self.connection.selectedTeamId == teamId else { return }
                await MainActor.run {
                    self.pollingDeploymentId = nil
                    self.pollProgress = nil
                    self.lastError = error.localizedDescription
                }
            }
        }
        await pollTask?.value
    }

    private func loadDemo() async {
        connection = buildDemoConnection()
        projects = buildDemoProjects()
        selectedProjectId = DemoIDs.portfolio
        deployments = buildDemoDeployments(projectId: DemoIDs.portfolio)
        publishWidgetSnapshot()
        await restoreHistory(scope: .demo)
        do {
            if try await evidenceStore.loadHistory(scope: .demo) == nil {
                recentActivity = buildDemoActivity().map(sanitizedActivity)
                try await evidenceStore.replaceHistory(recentActivity, scope: .demo)
            }
        } catch {
            historyStorageError = error.localizedDescription
        }
        tokenSource = .pat
    }

    private func connectWithStoredToken(_ token: String) async -> ConnectionAttemptResult {
        generation += 1
        let gen = generation
        isBusy = true
        defer { if gen == generation { isBusy = false } }
        do {
            let live = clientFactory(token)
            let user = try await live.getUser()
            let teams = try await live.listTeams()
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            try await finishConnect(
                api: live,
                token: token,
                user: user,
                teams: teams,
                detail: "Restored personal access token session",
                generation: gen
            )
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            return .connected(.pat)
        } catch {
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            connection.status = .error
            connection.errorMessage = error.localizedDescription
            lastError = error.localizedDescription
            return .rejected(error.localizedDescription)
        }
    }

    private func finishConnect(
        api: any VercelAPIClient,
        token: String,
        user: VercelUser,
        teams: [VercelTeam],
        detail: String,
        generation gen: Int
    ) async throws {
        let requestedScopeGeneration = scopeGeneration
        let savedTeam = keychain.load(KeychainStore.Key.selectedTeamId)
        let savedAccount = keychain.load(KeychainStore.Key.evidenceUserID)
        let sameAccount = savedAccount == nil || savedAccount == user.id
        let selectedTeamId: TeamID?
        if sameAccount, savedTeam == KeychainStore.personalTeamSelection { selectedTeamId = nil }
        else if sameAccount, teams.contains(where: { $0.id == savedTeam }) { selectedTeamId = savedTeam }
        else { selectedTeamId = teams.first?.id }
        let list = try await api.listProjects(teamId: selectedTeamId)
        guard gen == generation, requestedScopeGeneration == scopeGeneration else {
            throw VercelAPIError(status: nil, detail: "Connection attempt was superseded.")
        }
        // Save only a fully authenticated identity; restore previous credentials if any Keychain write fails.
        let keys = [KeychainStore.Key.tokenSource, KeychainStore.Key.evidenceUserID, KeychainStore.Key.selectedTeamId, KeychainStore.Key.accessToken]
        let previousValues = keys.map { ($0, keychain.load($0)) }
        do {
            try keychain.save(TokenSource.pat.rawValue, key: KeychainStore.Key.tokenSource)
            try keychain.save(user.id, key: KeychainStore.Key.evidenceUserID)
            try keychain.saveTeamSelection(selectedTeamId)
            try keychain.save(token, key: KeychainStore.Key.accessToken)
        } catch {
            for (key, value) in previousValues {
                if let value { try? keychain.save(value, key: key) } else { keychain.delete(key) }
            }
            throw error
        }
        cancelBriefGeneration(clearCache: true)
        scopeGeneration += 1
        let installedScopeGeneration = scopeGeneration
        invalidateWidget()
        pollTask?.cancel()
        pollingDeploymentId = nil
        pollProgress = nil
        pendingMutation = nil
        selectedProjectId = nil
        deployments = []
        selectedDeployment = nil
        deploymentSelection = nil
        opsNarrative = nil
        envDrift = nil
        incident = nil
        incidentDeploymentId = nil
        client = api
        tokenSource = .pat
        connection = VercelConnection(
            status: .connected,
            user: user,
            teams: teams,
            selectedTeamId: selectedTeamId,
            errorMessage: nil
        )
        projects = list
        publishWidgetSnapshot()
        let scope = EvidenceScope(accountID: user.id, teamID: selectedTeamId)
        if evidenceScope != scope { await restoreHistory(scope: scope) }
        guard gen == generation else {
            throw VercelAPIError(status: nil, detail: "Connection attempt was superseded.")
        }
        guard scopeGeneration == installedScopeGeneration, connection.user?.id == user.id,
              connection.selectedTeamId == selectedTeamId else { return }
        appendActivity(kind: .connect, title: "Connected to Vercel", detail: detail, outcome: .success)
        appendActivity(
            kind: .refreshProjects,
            title: "Loaded projects",
            detail: "\(list.count) project(s) (list without N+1 deploy fan-out)",
            outcome: .success
        )
        let savedProject = keychain.load(KeychainStore.Key.selectedProjectId)
        if let savedProject, list.contains(where: { $0.id == savedProject }) {
            selectedProjectId = savedProject
            try? await loadDeploymentsThrowing(savedProject, api: api, teamId: selectedTeamId)
        } else {
            keychain.delete(KeychainStore.Key.selectedProjectId)
        }
    }

    private func loadDeploymentsThrowing(_ projectId: ProjectID, api: any VercelAPIClient, teamId: TeamID?) async throws {
        let scope = scopeGeneration
        let list = try await api.listDeployments(projectId: projectId, teamId: teamId, limit: 30)
        guard scope == scopeGeneration, selectedProjectId == projectId, connection.selectedTeamId == teamId else { return }
        deployments = list
        publishWidgetSnapshot()
    }

    private func invalidateWidget() {
        widgetRevision = UUID().uuidString
        keychain.widgetStore.clear(source: isDemoMode ? .demo : nil)
        WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
        TaktungShortcuts.updateAppShortcutParameters()
    }

    private func publishWidgetSnapshot() {
        guard let account = connection.user?.id,
              connection.isConnected else { return }
        if isDemoMode, keychain.widgetStore.token() != nil { return }
        let source: WidgetDeploymentSnapshot.Source = isDemoMode ? .demo : .live
        var snapshots: [WidgetDeploymentSnapshot] = []
        if isDemoMode {
            for project in projects {
                snapshots.append(.make(projectID: project.id, projectName: project.name, accountID: account,
                    teamID: connection.selectedTeamId, revision: widgetRevision, source: .demo,
                    deployments: buildDemoDeployments(projectId: project.id)))
            }
            snapshots.append(.make(projectID: WidgetAccountContext.allProjectsID, projectName: "All projects", accountID: account,
                teamID: connection.selectedTeamId, revision: widgetRevision, source: .demo,
                deployments: projects.flatMap { buildDemoDeployments(projectId: $0.id) }))
        } else if let project = selectedProject, !deployments.isEmpty {
            snapshots.append(.make(projectID: project.id, projectName: project.name, accountID: account,
                teamID: connection.selectedTeamId, revision: widgetRevision, source: .live, deployments: deployments))
        }
        let context = WidgetAccountContext(revision: widgetRevision, accountID: account,
            teamID: connection.selectedTeamId, source: source,
            projects: projects.map { .init(id: $0.id, name: $0.name) }, cachedSnapshots: snapshots)
        if keychain.widgetStore.save(context) {
            WidgetCenter.shared.reloadTimelines(ofKind: AppConfig.widgetKind)
            TaktungShortcuts.updateAppShortcutParameters()
        }
    }

    private func ensureAPI() async throws -> any VercelAPIClient {
        if let client { return client }
        if isDemoMode {
            let demo = DemoAPIClient()
            client = demo
            return demo
        }
        throw VercelAPIError(status: 401, detail: "Not connected.")
    }

    private func appendActivity(
        kind: ActivityKind,
        title: String,
        detail: String,
        outcome: ActivityOutcome,
        projectId: ProjectID? = nil,
        deploymentId: DeploymentID? = nil,
        id: String? = nil
    ) {
        guard let scope = evidenceScope else { return }
        let item = sanitizedActivity(ActivityItem(
            id: id ?? newID(),
            kind: kind,
            title: title,
            detail: detail,
            outcome: outcome,
            createdAt: Date(),
            projectId: projectId,
            deploymentId: deploymentId,
            projectName: projects.first { $0.id == projectId }.map(siteTitle)
        ))
        recentActivity.removeAll { $0.id == item.id }
        recentActivity.insert(item, at: 0)
        recentActivity = Array(recentActivity.prefix(LocalEvidenceStore.historyLimit))
        let previous = historyWriteTask
        let store = evidenceStore
        let pending = recentActivity
        historyWriteTask = Task { [weak self] in
            await previous?.value
            do {
                try await store.append(pending, scope: scope)
                if self?.evidenceScope == scope { self?.historyStorageError = nil }
            } catch {
                if self?.evidenceScope == scope { self?.historyStorageError = "History could not be saved. Existing records have been kept." }
            }
        }
    }

    // MARK: - On-device context: Field Log search, build explanations, Field Log summaries, Spotlight

    /// Rules first; Apple Intelligence reads only Field Log requests the rules cannot place.
    /// The model sees the request and loaded site names, never the journal.
    func interpretFieldLogSearch(_ text: String) async -> FieldLogInterpretation {
        let rules = FieldLogRules.parse(text, projects: projects)
        guard rules.needsModel, !isDemoMode else { return rules }
        refreshModelAvailability()
        guard onDeviceAvailable else { return rules }
        let scope = scopeGeneration
        let account = evidenceScope
        let draft = await fieldLogPlanner(text, projects.map(siteTitle))
        guard !Task.isCancelled, scope == scopeGeneration, account == evidenceScope, let draft,
              let reading = FieldLogModelPolicy.interpretation(draft, query: text, rules: rules, projects: projects) else {
            return rules
        }
        return reading
    }

    /// Key lines on every device; an on-device sentence when Apple Intelligence is
    /// available. Generation never holds the busy flag or blocks navigation.
    private func recordBuildFailure(deploymentID: DeploymentID, logs: [BuildLogLine]) {
        buildExplanationTask?.cancel()
        buildExplanationTask = nil
        guard let excerpt = BuildFailurePolicy.excerpt(from: logs) else {
            buildFailure = nil
            return
        }
        buildFailure = BuildFailureEvidence(deploymentID: deploymentID, excerpt: excerpt)
        guard !isDemoMode else { return }
        refreshModelAvailability()
        guard onDeviceAvailable, BuildFailurePolicy.prompt(excerpt) != nil else { return }
        let scope = scopeGeneration
        let explainer = buildExplainer
        buildFailure?.isExplaining = true
        buildExplanationTask = Task { [weak self] in
            let response = await explainer(excerpt)
            guard let self, !Task.isCancelled, scope == self.scopeGeneration,
                  self.buildFailure?.deploymentID == deploymentID, self.buildFailure?.excerpt == excerpt else { return }
            self.buildFailure?.isExplaining = false
            self.buildFailure?.explanation = response.flatMap { BuildFailurePolicy.accept($0, excerpt: excerpt) }
        }
    }

    /// Site, team, account and reconnection changes discard on-device context and
    /// cancel its generation, so a late reply cannot land on another scope.
    private func clearOnDeviceContext() {
        buildExplanationTask?.cancel()
        buildExplanationTask = nil
        buildFailure = nil
        dismissFieldLogDigest()
    }

    /// Counts the last seven days on every device and, with Apple Intelligence,
    /// summarizes a bounded, redacted selection of those entries.
    func summarizeFieldLog(allSites: Bool) {
        digestTask?.cancel()
        digestTask = nil
        guard let account = evidenceScope else { return }
        let projectID = allSites ? nil : selectedProjectId
        let label = allSites || selectedProject == nil ? "All sites" : selectedProject.map(siteTitle) ?? "This site"
        let digest = FieldLogDigestPolicy.digest(entries: recentActivity, projectID: projectID, scopeLabel: label)
        fieldLogDigest = digest
        guard !isDemoMode else { return }
        refreshModelAvailability()
        guard onDeviceAvailable, let prompt = FieldLogDigestPolicy.prompt(digest, includeSite: projectID == nil) else { return }
        let scope = scopeGeneration
        let summarizer = fieldLogSummarizer
        fieldLogDigest?.isSummarizing = true
        digestTask = Task { [weak self] in
            let response = await summarizer(prompt)
            guard let self, !Task.isCancelled, scope == self.scopeGeneration, account == self.evidenceScope,
                  self.fieldLogDigest?.id == digest.id else { return }
            self.fieldLogDigest?.isSummarizing = false
            self.fieldLogDigest?.summary = response.flatMap { FieldLogDigestPolicy.accept($0, prompt: prompt) }
        }
    }

    func dismissFieldLogDigest() {
        digestTask?.cancel()
        digestTask = nil
        fieldLogDigest = nil
    }
}
