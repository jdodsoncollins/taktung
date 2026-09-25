import Foundation
import Observation

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
    var opsNarrative: OpsNarrative?
    var envDrift: EnvDriftReport?
    var incident: IncidentSummary?
    var lastError: String?
    var isBusy = false
    var isRehydrating = true
    var onDeviceAvailable = false
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

    var showsSearch: Bool {
        DemoMode.isEnabled || onDeviceAvailable
    }

    var canDiagnose: Bool {
        DemoMode.isEnabled || onDeviceAvailable
    }

    private let keychain = KeychainStore()
    private var client: (any VercelAPIClient)?
    private var pollTask: Task<Void, Never>?
    private var generation = 0

    func bootstrap() async {
        isRehydrating = true
        onDeviceAvailable = OnDevicePlanner.isAvailable
        defer { isRehydrating = false }

        if DemoMode.isEnabled {
            await loadDemo()
            return
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
        }
    }

    func enableDemo(_ enabled: Bool) async {
        DemoMode.setUserToggle(enabled)
        pollTask?.cancel()
        client = nil
        generation += 1
        lastError = nil
        opsNarrative = nil
        envDrift = nil
        incident = nil
        selectedDeployment = nil
        if enabled {
            keychain.eraseAll()
            await loadDemo()
        } else {
            connection = .empty()
            projects = []
            selectedProjectId = nil
            deployments = []
            recentActivity = []
            tokenSource = nil
        }
    }

    func connectWithToken(_ raw: String) async -> ConnectionAttemptResult {
        if DemoMode.isEnabled {
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
        connection.status = .connecting
        defer { isBusy = false }
        do {
            let live = LiveVercelAPIClient(tokenProvider: { token })
            let user = try await live.getUser()
            let teams = try await live.listTeams()
            guard gen == generation else { return .rejected("Connection attempt was superseded.") }
            try keychain.save(token, key: KeychainStore.Key.accessToken)
            try keychain.save(TokenSource.pat.rawValue, key: KeychainStore.Key.tokenSource)
            client = live
            tokenSource = .pat
            try await finishConnect(api: live, user: user, teams: teams, detail: "Signed in with personal access token", generation: gen)
            return .connected(.pat)
        } catch {
            connection.status = .error
            connection.errorMessage = error.localizedDescription
            lastError = error.localizedDescription
            return .rejected(error.localizedDescription)
        }
    }

    func disconnect() async {
        generation += 1
        pollTask?.cancel()
        client = nil
        keychain.eraseAll()
        connection = .empty()
        projects = []
        selectedProjectId = nil
        deployments = []
        selectedDeployment = nil
        recentActivity = []
        opsNarrative = nil
        envDrift = nil
        incident = nil
        tokenSource = nil
        lastError = nil
        appendActivity(
            kind: .disconnect,
            title: "Disconnected",
            detail: "Credentials and local selections erased",
            outcome: .info
        )
    }

    func selectTeam(_ teamId: TeamID?) async {
        guard !DemoMode.isEnabled else { return }
        connection.selectedTeamId = teamId
        if let teamId {
            try? keychain.save(teamId, key: KeychainStore.Key.selectedTeamId)
        } else {
            keychain.delete(KeychainStore.Key.selectedTeamId)
        }
        await refreshProjects()
    }

    func refreshProjects() async {
        guard let api = try? await ensureAPI() else { return }
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            let list = try await api.listProjects(teamId: connection.selectedTeamId)
            projects = list
            appendActivity(
                kind: .refreshProjects,
                title: "Loaded projects",
                detail: "\(list.count) project(s) (list without N+1 deploy fan-out)",
                outcome: .success
            )
            if let selectedProjectId, list.contains(where: { $0.id == selectedProjectId }) {
                await loadDeployments(selectedProjectId)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectProject(_ id: ProjectID?) async {
        selectedProjectId = id
        selectedDeployment = nil
        opsNarrative = nil
        envDrift = nil
        incident = nil
        if DemoMode.isEnabled {
            if let id {
                deployments = buildDemoDeployments(projectId: id)
            } else {
                deployments = []
            }
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
        do {
            let list = try await api.listDeployments(projectId: projectId, teamId: connection.selectedTeamId, limit: 30)
            deployments = list
            appendActivity(
                kind: .loadDeployments,
                title: "Loaded deployments",
                detail: "\(list.count) deployment(s)",
                outcome: .success,
                projectId: projectId
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectDeployment(_ id: DeploymentID?) async {
        guard let id else {
            selectedDeployment = nil
            return
        }
        if let existing = deployments.first(where: { $0.id == id }) {
            selectedDeployment = existing
        }
        guard let api = try? await ensureAPI() else { return }
        do {
            selectedDeployment = try await api.getDeployment(id: id, teamId: connection.selectedTeamId)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func runOpsBrief() async {
        guard let project = selectedProject else { return }
        isBusy = true
        defer { isBusy = false }
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
            polling: pollingDeploymentId != nil
        )
        var narrative = synthesizeOpsNarrative(ctx)
        if containsSecretLike(narrative.body) {
            lastError = "Brief contained secret-like text and was discarded."
            return
        }
        if let sentence = await OnDevicePlanner.brief(context: formatOpsNarrative(narrative)) {
            narrative = OpsNarrative(
                headline: narrative.headline,
                body: sentence,
                nextSteps: narrative.nextSteps,
                confidence: narrative.confidence,
                usedFields: narrative.usedFields,
                source: .appleFoundation
            )
        }
        opsNarrative = narrative
        appendActivity(
            kind: .note,
            title: "Diagnose",
            detail: narrative.headline,
            outcome: .success,
            projectId: project.id
        )
    }

    func runEnvDrift() async {
        guard let project = selectedProject, let api = try? await ensureAPI() else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let meta = try await api.listEnvVarMeta(projectId: project.id, teamId: connection.selectedTeamId)
            envDrift = analyzeEnvDrift(meta)
            appendActivity(
                kind: .envDrift,
                title: "Env drift",
                detail: envDrift?.summary ?? "Checked env names only",
                outcome: .success,
                projectId: project.id
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadBuildLogs(for id: DeploymentID) async -> [BuildLogLine] {
        guard let api = try? await ensureAPI() else { return [] }
        do {
            let lines = try await api.getBuildLogLines(id: id, teamId: connection.selectedTeamId, limit: 200)
            appendActivity(
                kind: .loadLogs,
                title: "Loaded build logs",
                detail: "\(lines.count) line(s)",
                outcome: .success,
                deploymentId: id
            )
            return lines
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    func runIncidentSummary() async {
        guard let project = selectedProject else { return }
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
            let driftKeys = envDrift?.findings.filter { $0.kind == .missingInProduction }.map(\.key) ?? []
            incident = summarizeFailedDeployment(
                failed: failed,
                lastSuccess: project.lastSuccessfulDeployment,
                logLines: logs,
                missingProductionEnvKeys: driftKeys
            )
            appendActivity(
                kind: .incidentSummary,
                title: incident?.headline ?? "Incident",
                detail: incident?.likelyCause ?? "See evidence",
                outcome: .info,
                projectId: project.id,
                deploymentId: failed.id
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func requestMutation(mode: MutationMode) {
        guard let project = selectedProject, let deploy = selectedDeployment ?? project.productionDeployment else {
            lastError = "Pick a deployment first."
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
        guard mutationConfirmationMatches(pending.action, mutationConfirmation(for: pending.action)) else {
            lastError = "Confirmation did not match the planned mutation."
            return
        }
        if DemoMode.isEnabled {
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
            let created = try await api.redeploy(
                deploymentId: deploymentId,
                projectId: projectId,
                teamId: teamId,
                target: target
            )
            appendActivity(
                kind: pending.mode == .rollback ? .rollback : pending.mode == .promote ? .promote : .redeploy,
                title: pending.title,
                detail: "Accepted \(created.id). Polling for READY.",
                outcome: .info,
                projectId: projectId,
                deploymentId: created.id
            )
            await pollUntilReady(created.id, teamId: teamId)
        } catch {
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

    func clearActivity() {
        recentActivity = []
    }

    func routeSearch(_ query: String) -> String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return "Choose an example, or type a site name." }
        if q == "ready" || q.contains(" ready") {
            let ready = deployments.filter { $0.state == .ready }
            if let site = selectedProject {
                let state = site.productionDeployment?.state.rawValue ?? "NO PROD"
                return "\(siteTitle(site)) production is \(state). \(ready.count) READY deploy(s) loaded."
            }
            return ready.isEmpty
                ? "No READY deployments in the loaded list."
                : "\(ready.count) READY deploy(s) across loaded sites."
        }
        if q.contains("env") {
            return envDrift?.summary ?? "Run Env drift from a selected site. Names only — never values."
        }
        if q.contains("fail") {
            let failed = deployments.filter { isFailedState($0.state) }
            return failed.isEmpty
                ? "No failed deployments in the loaded list."
                : "\(failed.count) failed deploy(s). Open Deploys → Failed."
        }
        if let project = rankSites(projects, query: query).first {
            return "\(siteTitle(project)) · \(project.productionDeployment?.state.rawValue ?? "NO PROD")"
        }
        return "No match in loaded sites."
    }

    private func pollUntilReady(_ id: DeploymentID, teamId: TeamID?) async {
        pollTask?.cancel()
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
                        return d.state
                    }
                )
                await MainActor.run {
                    self.pollingDeploymentId = nil
                    self.pollProgress = nil
                    self.appendActivity(
                        kind: .deploymentPoll,
                        title: result.isReady ? "Deployment READY" : "Deploy poll finished",
                        detail: result.summary,
                        outcome: result.isReady ? .success : .failure,
                        deploymentId: id
                    )
                }
                if let projectId = await MainActor.run(body: { self.selectedProjectId }) {
                    await self.loadDeployments(projectId)
                }
            } catch {
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
        recentActivity = buildDemoActivity()
        tokenSource = .pat
        onDeviceAvailable = true
    }

    private func connectWithStoredToken(_ token: String) async -> ConnectionAttemptResult {
        generation += 1
        let gen = generation
        isBusy = true
        defer { isBusy = false }
        do {
            let live = LiveVercelAPIClient(tokenProvider: { token })
            let user = try await live.getUser()
            let teams = try await live.listTeams()
            client = live
            try await finishConnect(
                api: live,
                user: user,
                teams: teams,
                detail: "Restored personal access token session",
                generation: gen
            )
            return .connected(.pat)
        } catch {
            connection.status = .error
            connection.errorMessage = error.localizedDescription
            lastError = error.localizedDescription
            return .rejected(error.localizedDescription)
        }
    }

    private func finishConnect(
        api: any VercelAPIClient,
        user: VercelUser,
        teams: [VercelTeam],
        detail: String,
        generation gen: Int
    ) async throws {
        let savedTeam = keychain.load(KeychainStore.Key.selectedTeamId)
        let selectedTeamId = teams.contains(where: { $0.id == savedTeam }) ? savedTeam : teams.first?.id
        let list = try await api.listProjects(teamId: selectedTeamId)
        guard gen == generation else { throw VercelAPIError(status: nil, detail: "Connection attempt was superseded.") }
        connection = VercelConnection(
            status: .connected,
            user: user,
            teams: teams,
            selectedTeamId: selectedTeamId,
            errorMessage: nil
        )
        projects = list
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
        }
    }

    private func loadDeploymentsThrowing(_ projectId: ProjectID, api: any VercelAPIClient, teamId: TeamID?) async throws {
        let list = try await api.listDeployments(projectId: projectId, teamId: teamId, limit: 30)
        deployments = list
    }

    private func ensureAPI() async throws -> any VercelAPIClient {
        if let client { return client }
        if DemoMode.isEnabled {
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
        deploymentId: DeploymentID? = nil
    ) {
        let item = ActivityItem(
            id: newID(),
            kind: kind,
            title: title,
            detail: detail,
            outcome: outcome,
            createdAt: Date(),
            projectId: projectId,
            deploymentId: deploymentId
        )
        recentActivity.insert(item, at: 0)
        if recentActivity.count > 200 {
            recentActivity = Array(recentActivity.prefix(200))
        }
    }
}
