import SwiftUI
import WebKit

/// Fresh, anonymous captures at a fixed viewport. Does not reuse thumbnail caches or Safari credentials.
@MainActor
final class VisualPageCapture: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let expectedURL: URL
    private var continuation: CheckedContinuation<Data, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var completed = false

    init(url: URL) {
        expectedURL = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(x: -4000, y: 0, width: 390, height: 844), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.overrideUserInterfaceStyle = .light
        webView.isUserInteractionEnabled = false
        webView.accessibilityElementsHidden = true
    }

    func capture(in host: UIView, demoHTML: String? = nil) async throws -> Data {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                host.addSubview(webView)
                if let demoHTML { webView.loadHTMLString(demoHTML, baseURL: expectedURL) }
                else { webView.load(URLRequest(url: expectedURL, cachePolicy: .reloadIgnoringLocalCacheData)) }
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(15)) }
                    catch { return }
                    self?.finish(.failure(VisualComparisonError.unavailable))
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.targetFrame?.isMainFrame != false else { return .allow }
        guard let url = navigationAction.request.url,
              url.scheme == "https", url.host == expectedURL.host,
              url.user == nil, url.password == nil,
              !isUnusablePreviewLocation(url.absoluteString) else {
            finish(.failure(VisualComparisonError.protectedPage))
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse,
           response.statusCode >= 400 {
            finish(.failure(response.statusCode == 401 || response.statusCode == 403
                            ? VisualComparisonError.protectedPage : VisualComparisonError.unavailable))
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            guard !completed else { return }
            do {
                // Wait for fonts, visible images, and two paint frames. The overall timeout still applies.
                let result = try await webView.callAsyncJavaScript("""
                    await document.fonts.ready;
                    await Promise.all(Array.from(document.images).filter(i => i.getBoundingClientRect().top < 844)
                      .map(i => i.decode().catch(() => {})));
                    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
                    return {href: location.href, title: document.title};
                    """, arguments: [:], in: nil, contentWorld: .page)
                guard !completed else { return }
                let info = result as? [String: Any]
                guard let href = info?["href"] as? String, URL(string: href)?.host == expectedURL.host,
                      !isUnusablePreviewLocation(href, title: info?["title"] as? String ?? "") else {
                    finish(.failure(VisualComparisonError.protectedPage))
                    return
                }
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(x: 0, y: 0, width: 390, height: 844)
                config.snapshotWidth = 390
                config.afterScreenUpdates = true
                let image = try await webView.takeSnapshot(configuration: config)
                guard let png = image.pngData() else { throw VisualComparisonError.invalidImage }
                finish(.success(png))
            } catch {
                finish(.failure(VisualComparisonError.unavailable))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish(.failure(VisualComparisonError.unavailable))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        finish(.failure(VisualComparisonError.unavailable))
    }

    private func finish(_ result: Result<Data, any Error>) {
        guard !completed else { return }
        completed = true
        timeoutTask?.cancel()
        webView.navigationDelegate = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        continuation?.resume(with: result)
        continuation = nil
    }
}

@MainActor
final class VisualCaptureHostRegistry {
    static let shared = VisualCaptureHostRegistry()
    weak var host: UIView?

    func capture(deployment: VercelDeploymentSummary, projectID: ProjectID, route: String) async throws -> VisualCapture {
        guard let host, host.window != nil else { throw VisualComparisonError.detached }
        let url = try comparisonURL(deployment: deployment, route: route)
        let isDemo = DemoMode.isEnabled
        let job = VisualPageCapture(url: url)
        let png = try await job.capture(in: host, demoHTML: isDemo ? DemoPreview.comparisonHTML(deploymentID: deployment.id, route: route) : nil)
        try Task.checkCancellation()
        return VisualCapture(projectID: projectID, deploymentID: deployment.id,
                             deploymentTitle: redactBuildLog(deploymentTitle(deployment)), commit: shortSha(deployment),
                             route: route, capturedAt: .now, png: png)
    }
}

struct VisualCaptureHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private final class HostView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { VisualCaptureHostRegistry.shared.host = self }
        }
    }
}
