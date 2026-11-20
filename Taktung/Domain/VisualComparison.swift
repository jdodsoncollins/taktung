import Foundation

struct EvidenceScope: Codable, Hashable, Sendable {
    var accountID: String
    var teamID: String?
    var isDemo = false

    static let demo = EvidenceScope(accountID: "demo", teamID: nil, isDemo: true)
}

enum VisualComparisonError: LocalizedError {
    case invalidRoute, unavailable, protectedPage, detached, staleScope, invalidImage, corruptStore
    case timedOut, httpStatus(Int), network(String)

    var errorDescription: String? {
        switch self {
        case .invalidRoute: "Enter a path such as / or /about, without a host, query, or fragment."
        case .unavailable: "The page could not be captured. Check its availability and try again."
        case .timedOut: "The page did not become ready within \(Int(visualCaptureTimeout.components.seconds)) seconds. Try again."
        case .httpStatus(let code): "The page returned HTTP \(code)."
        case .network(let reason): "The page could not be loaded. \(reason)"
        case .protectedPage: "This page requires authentication or redirected elsewhere. Review it in your browser."
        case .detached: "Open the app to capture a page."
        case .staleScope: "The selected account or site changed. Open Compare again."
        case .invalidImage: "The saved image could not be read. Capture a new baseline."
        case .corruptStore: "Local evidence could not be read. Existing files have been kept."
        }
    }
}

/// Whole-capture budget for one page. Readiness waits inside it are bounded separately, so a slow
/// below-the-fold image, analytics request or third-party frame cannot hold the capture open.
let visualCaptureTimeout: Duration = .seconds(30)

/// Vercel injects its toolbar frame into preview deployments only. It is not part of the site under
/// review, and loading it would make preview-versus-production captures differ for reasons outside the change.
func isVercelToolbarFrame(_ url: URL?) -> Bool {
    guard let host = url?.host?.lowercased() else { return false }
    return host == "vercel.live" || host.hasSuffix(".vercel.live")
}

/// Main-frame failures map to the reason a person can act on.
func visualCaptureError(statusCode: Int) -> VisualComparisonError {
    statusCode == 401 || statusCode == 403 ? .protectedPage : .httpStatus(statusCode)
}

/// `nil` when a newer main-frame navigation (such as a client-side redirect) replaced this one;
/// the capture keeps waiting for that document within its timeout.
func visualCaptureError(loadFailure error: any Error) -> VisualComparisonError? {
    let ns = error as NSError
    guard ns.domain == NSURLErrorDomain else { return .unavailable }
    return ns.code == NSURLErrorCancelled ? nil : .network(ns.localizedDescription)
}

/// Only a route within the selected deployment, never a free-form URL or credential-bearing query.
func comparisonRoute(_ raw: String) throws -> String {
    let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard path.hasPrefix("/"), !path.hasPrefix("//"),
          !path.contains("\\"), !path.contains("?"), !path.contains("#"),
          !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
          let components = URLComponents(string: path), components.host == nil,
          components.scheme == nil, components.query == nil, components.fragment == nil,
          !components.path.split(separator: "/").contains(where: { $0 == ".." || $0 == "." }) else {
        throw VisualComparisonError.invalidRoute
    }
    return components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
}

func comparisonURL(deployment: VercelDeploymentSummary, route: String) throws -> URL {
    guard shouldProbeDeploymentPreview(state: deployment.state, url: deployment.url),
          let absolute = absoluteDeploymentURL(deployment.url),
          var components = URLComponents(string: absolute), components.host != nil,
          components.scheme == "https", components.user == nil, components.password == nil else {
        throw VisualComparisonError.unavailable
    }
    components.percentEncodedPath = try comparisonRoute(route)
    components.query = nil
    components.fragment = nil
    guard let url = components.url else { throw VisualComparisonError.invalidRoute }
    return url
}

func comparisonBaselines(project: VercelProject, deployments: [VercelDeploymentSummary], candidateID: DeploymentID) -> [VercelDeploymentSummary] {
    var seen = Set<DeploymentID>()
    return ([project.productionDeployment].compactMap { $0 } + deployments)
        .filter { $0.id != candidateID && shouldProbeDeploymentPreview(state: $0.state, url: $0.url) && seen.insert($0.id).inserted }
}

struct VisualCapture: Codable, Sendable, Identifiable {
    var id = UUID().uuidString
    var projectID: ProjectID
    var deploymentID: DeploymentID
    var deploymentTitle: String
    var commit: String
    var route: String
    var capturedAt: Date
    var viewportWidth = 390
    var viewportHeight = 844
    var png: Data
}

func sanitizedActivity(_ item: ActivityItem) -> ActivityItem {
    var safe = item
    safe.title = String(redactBuildLog(item.title).prefix(180))
    safe.detail = String(redactBuildLog(item.detail).prefix(8_000))
    safe.projectName = item.projectName.map { String(redactBuildLog($0).prefix(180)) }
    return safe
}

func historyExport(_ items: [ActivityItem]) -> String {
    let formatter = ISO8601DateFormatter()
    return (["Taktung activity history", "Actions and observations recorded on this device."] + items.map { raw in
        let item = sanitizedActivity(raw)
        return "\n\(formatter.string(from: item.createdAt)) · \(item.outcome.rawValue.uppercased())\n\(item.displayTitle)\n\(item.projectName ?? item.projectId ?? "Account")\n\(item.displayDetail)"
    }).joined(separator: "\n")
}
