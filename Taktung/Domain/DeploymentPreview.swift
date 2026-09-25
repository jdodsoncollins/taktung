import Foundation

/// Probe only READY URLs. Error and building pages are Vercel chrome, not the site.
func shouldProbeDeploymentPreview(state: DeploymentState, url: String?) -> Bool {
    guard let abs = absoluteDeploymentURL(url) else { return false }
    return state == .ready && !isUnusablePreviewLocation(abs)
}

func absoluteDeploymentURL(_ url: String?) -> String? {
    guard let trimmed = url?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
        return trimmed
    }
    return "https://\(trimmed.replacingOccurrences(of: "^//", with: "", options: .regularExpression))"
}

/// Vercel SSO and login walls are not the deployed site.
func isUnusablePreviewLocation(_ href: String, title: String = "") -> Bool {
    guard let parsed = URL(string: href), let host = parsed.host?.lowercased() else { return true }
    let path = parsed.path.lowercased()
    if host == "vercel.com" || host == "www.vercel.com" { return true }
    if host.hasSuffix("vercel.com"),
       path.contains("/login") || path.contains("/sso") || path.contains("/authentication") {
        return true
    }
    let heading = title.lowercased()
    if heading.contains("authentication required") { return true }
    if heading.contains("vercel"), heading.contains("login") || heading.contains("sso") {
        return true
    }
    return false
}
