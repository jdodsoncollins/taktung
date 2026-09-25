import Foundation

typealias TeamID = String
typealias ProjectID = String
typealias DeploymentID = String

enum DeploymentState: String, Sendable, Codable, Hashable {
    case blocked = "BLOCKED"
    case building = "BUILDING"
    case error = "ERROR"
    case initializing = "INITIALIZING"
    case queued = "QUEUED"
    case ready = "READY"
    case canceled = "CANCELED"
    case deleted = "DELETED"
    case unknown = "UNKNOWN"

    static func map(_ raw: String?) -> DeploymentState {
        guard let raw else { return .unknown }
        return DeploymentState(rawValue: raw.uppercased()) ?? .unknown
    }
}

enum DeploymentTarget: String, Sendable, Codable, Hashable {
    case production
    case preview
    case development
}

enum AttentionReason: String, Sendable, Codable, Hashable {
    case latestProductionFailed = "latest_production_failed"
    case building
    case noProduction = "no_production"
    case staleSuccess = "stale_success"
    case recentFailure = "recent_failure"
    case none
}

enum ConnectionStatus: String, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

enum ActivityOutcome: String, Sendable, Codable {
    case success
    case failure
    case canceled
    case info
}

enum ActivityKind: String, Sendable, Codable {
    case connect
    case disconnect
    case refreshProjects = "refresh_projects"
    case loadDeployments = "load_deployments"
    case loadLogs = "load_logs"
    case incidentSummary = "incident_summary"
    case envDrift = "env_drift"
    case domainDiagnostics = "domain_diagnostics"
    case deploymentCompare = "deployment_compare"
    case observability
    case firewall
    case featureFlags = "feature_flags"
    case runtimeLogs = "runtime_logs"
    case deploymentPoll = "deployment_poll"
    case redeploy
    case promote
    case rollback
    case planExecute = "plan_execute"
    case inspectFunctions = "inspect_functions"
    case note
}

enum DataAvailability: String, Sendable, Codable {
    case ok
    case noData = "no_data"
    case unavailableForPlan = "unavailable_for_plan"
    case notEnabled = "not_enabled"
    case temporarilyUnavailable = "temporarily_unavailable"
}

struct VercelTeam: Sendable, Hashable, Identifiable {
    var id: TeamID
    var name: String
    var slug: String
}

struct VercelUser: Sendable, Hashable {
    var id: String
    var name: String?
    var username: String
    var email: String?
}

struct GitMeta: Sendable, Hashable {
    var githubCommitRef: String? = nil
    var githubCommitSha: String? = nil
    var githubCommitMessage: String? = nil
    var githubCommitAuthorName: String? = nil
    var githubCommitAuthorLogin: String? = nil
}

struct LambdaOutput: Sendable, Hashable {
    var path: String
    var functionName: String
    var readyState: String?
}

struct VercelDeploymentSummary: Sendable, Hashable, Identifiable {
    var id: DeploymentID
    var url: String?
    var name: String
    var state: DeploymentState
    var target: DeploymentTarget?
    var createdAt: TimeInterval
    var readyAt: TimeInterval?
    var buildingAt: TimeInterval?
    var source: String?
    /// GitHub / Vercel username who created the deploy. Never an email.
    var creatorUsername: String?
    var isRollbackCandidate: Bool?
    var region: String?
    var meta: GitMeta
    var inspectorUrl: String?
    var aliases: [String]?
    var buildDurationMs: Double?
    var lambdaOutputs: [LambdaOutput]?
}

struct ProjectLink: Sendable, Hashable {
    var type: String
    var repo: String?
    var org: String?
}

struct VercelProject: Sendable, Hashable, Identifiable {
    var id: ProjectID
    var name: String
    var framework: String?
    var nodeVersion: String?
    var primaryDomain: String?
    var productionDeployment: VercelDeploymentSummary?
    var latestDeployment: VercelDeploymentSummary?
    var lastSuccessfulDeployment: VercelDeploymentSummary?
    var latestFailedDeployment: VercelDeploymentSummary?
    var needsAttention: Bool
    var attentionReason: AttentionReason
    var teamId: TeamID?
    var link: ProjectLink?
}

struct VercelConnection: Sendable {
    var status: ConnectionStatus
    var user: VercelUser?
    var teams: [VercelTeam]
    var selectedTeamId: TeamID?
    var errorMessage: String?

    var isConnected: Bool { status == .connected && user != nil }

    static func empty() -> VercelConnection {
        VercelConnection(
            status: .disconnected,
            user: nil,
            teams: [],
            selectedTeamId: nil,
            errorMessage: nil
        )
    }
}

struct ActivityItem: Sendable, Identifiable, Hashable {
    var id: String
    var kind: ActivityKind
    var title: String
    var detail: String
    var outcome: ActivityOutcome
    var createdAt: Date
    var projectId: ProjectID?
    var deploymentId: DeploymentID?
}

/// Env var metadata only — never secret values.
struct EnvVarMeta: Sendable, Hashable, Identifiable {
    var id: String
    var key: String
    var type: String
    var target: [String]
    var gitBranch: String? = nil
    var createdAt: TimeInterval? = nil
    var updatedAt: TimeInterval? = nil
}

struct BuildLogLine: Sendable, Hashable {
    var text: String
    var type: String?
    var created: TimeInterval?
}

func newID() -> String {
    UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
}
