import SwiftUI
import WebKit

/// Fresh, anonymous captures at a fixed viewport. Does not reuse thumbnail caches or Safari credentials.
///
/// The snapshot is taken once the first viewport is ready: the document has parsed, web fonts and
/// on-screen images have settled (each wait bounded), and two frames have painted. It does not wait
/// for the window `load` event, which also covers below-the-fold images, analytics and third-party
/// frames and can exceed the capture budget on a phone even when the visible page is complete.
@MainActor
final class VisualPageCapture: NSObject, WKNavigationDelegate {
    static let viewport = CGSize(width: 390, height: 844)

    private let webView: WKWebView
    private let expectedURL: URL
    private let timeout: Duration
    private let settleBudgetMilliseconds: Int
    private var continuation: CheckedContinuation<Data, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var completed = false
    private var loadFinished = false
    private var readinessInFlight = false
    private var documentGeneration = 0

    init(url: URL, configuration: WKWebViewConfiguration = WKWebViewConfiguration(),
         timeout: Duration = visualCaptureTimeout, settleBudgetMilliseconds: Int = 6_000) {
        expectedURL = url
        self.timeout = timeout
        self.settleBudgetMilliseconds = settleBudgetMilliseconds
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(origin: CGPoint(x: -4000, y: 0), size: Self.viewport), configuration: configuration)
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
                let timeout = self.timeout
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) }
                    catch { return }
                    self?.finish(.failure(VisualComparisonError.timedOut))
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.targetFrame?.isMainFrame != false else {
            return isVercelToolbarFrame(navigationAction.request.url) ? .cancel : .allow
        }
        // The main frame must stay on the requested page's origin. `comparisonURL` only issues HTTPS origins.
        guard let url = navigationAction.request.url,
              url.scheme == expectedURL.scheme, url.host == expectedURL.host, url.port == expectedURL.port,
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
            finish(.failure(visualCaptureError(statusCode: response.statusCode)))
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // A new main document replaces any readiness check still waiting on the previous one.
        documentGeneration += 1
        readinessInFlight = false
        loadFinished = false
        beginReadiness()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadFinished = true
        beginReadiness()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        if let failure = visualCaptureError(loadFailure: error) { finish(.failure(failure)) }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        if let failure = visualCaptureError(loadFailure: error) { finish(.failure(failure)) }
    }

    private func beginReadiness() {
        guard !completed, !readinessInFlight else { return }
        readinessInFlight = true
        let generation = documentGeneration
        Task { @MainActor in
            do {
                let result = try await webView.callAsyncJavaScript(Self.readinessScript, arguments: [
                    "viewportHeight": Self.viewport.height, "budget": settleBudgetMilliseconds,
                ], in: nil, contentWorld: .defaultClient)
                guard !completed, generation == documentGeneration else { return }
                let info = result as? [String: Any]
                guard let href = info?["href"] as? String, URL(string: href)?.host == expectedURL.host,
                      !isUnusablePreviewLocation(href, title: info?["title"] as? String ?? "") else {
                    finish(.failure(VisualComparisonError.protectedPage))
                    return
                }
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(origin: .zero, size: Self.viewport)
                config.snapshotWidth = NSNumber(value: Double(Self.viewport.width))
                config.afterScreenUpdates = true
                let image = try await webView.takeSnapshot(configuration: config)
                guard !completed, generation == documentGeneration else { return }
                guard let png = image.pngData() else { throw VisualComparisonError.invalidImage }
                finish(.success(png))
            } catch {
                guard !completed, generation == documentGeneration else { return }
                readinessInFlight = false
                // Before `load`, the document may still be replacing itself; `didFinish` retries once.
                if loadFinished { finish(.failure(VisualComparisonError.unavailable)) }
            }
        }
    }

    /// Runs in an isolated content world so page scripts cannot replace the promises it relies on.
    /// Each wait is bounded by `budget`; the overall capture timeout still applies.
    private static let readinessScript = """
        const settle = (promise) => Promise.race([promise, new Promise(r => setTimeout(r, budget))]);
        if (document.readyState === 'loading') {
          await new Promise(r => document.addEventListener('DOMContentLoaded', r, { once: true }));
        }
        if (document.fonts) { await settle(document.fonts.ready); }
        const onScreen = Array.from(document.images).filter(image => {
          const box = image.getBoundingClientRect();
          return box.width > 0 && box.height > 0 && box.bottom > 0 && box.top < viewportHeight;
        });
        await settle(Promise.all(onScreen.map(image => image.decode().catch(() => {}))));
        await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
        return { href: location.href, title: document.title };
        """

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
