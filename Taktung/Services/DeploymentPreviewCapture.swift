import SwiftUI
import WebKit

/// One off-screen web view. Loads READY deployment URLs in series and snapshots the painted page.
@MainActor
final class PreviewCaptureCenter: NSObject, WKNavigationDelegate {
    static let shared = PreviewCaptureCenter()

    static let captureWidth: CGFloat = 360
    static let minHeight: CGFloat = 640
    static let maxHeight: CGFloat = 1600
    private let timeout: TimeInterval = 8

    private var webView: WKWebView?
    private var images: [String: UIImage] = [:]
    private var misses = Set<String>()
    private var queue: [String] = []
    private var waiters: [String: [CheckedContinuation<UIImage?, Never>]] = [:]
    private var current: String?
    private var timeoutTask: Task<Void, Never>?

    func cachedImage(for pageURL: String) -> UIImage? {
        images[pageURL]
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
        webView.frame = CGRect(x: 0, y: 0, width: Self.captureWidth, height: Self.minHeight)
        pump()
    }

    func image(for pageURL: String, prioritize: Bool = false) async -> UIImage? {
        if let hit = images[pageURL] { return hit }
        if misses.contains(pageURL) { return nil }
        return await withCheckedContinuation { continuation in
            waiters[pageURL, default: []].append(continuation)
            if current != pageURL, !queue.contains(pageURL) {
                if prioritize { queue.insert(pageURL, at: 0) } else { queue.append(pageURL) }
            }
            pump()
        }
    }

    private func pump() {
        guard current == nil, webView != nil, let next = queue.first else { return }
        queue.removeFirst()
        current = next
        misses.remove(next)
        webView?.frame.size = CGSize(width: Self.captureWidth, height: Self.minHeight)
        guard let url = URL(string: next) else {
            finish(nil)
            return
        }
        webView?.load(URLRequest(url: url))
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.finish(nil)
        }
    }

    private func finish(_ image: UIImage?) {
        guard let page = current else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        current = nil
        if let image {
            images[page] = image
        } else {
            misses.insert(page)
        }
        let pending = waiters.removeValue(forKey: page) ?? []
        pending.forEach { $0.resume(returning: image) }
        pump()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard current != nil else { return }
        let script = """
        JSON.stringify({
          h: Math.max(document.body ? document.body.scrollHeight : 0, document.documentElement ? document.documentElement.scrollHeight : 0, 640),
          w: window.innerWidth || 360,
          title: document.title || '',
          href: String(location.href)
        })
        """
        webView.evaluateJavaScript(script) { [weak self] value, _ in
            Task { @MainActor in
                self?.handleReady(value, webView: webView)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(nil)
    }

    private func handleReady(_ value: Any?, webView: WKWebView) {
        guard current != nil else { return }
        let object = (value as? String).flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        let href = object?["href"] as? String ?? current ?? ""
        let title = object?["title"] as? String ?? ""
        if isUnusablePreviewLocation(href, title: title) {
            finish(nil)
            return
        }
        let pageW = CGFloat((object?["w"] as? Double) ?? Double(Self.captureWidth))
        let rawH = CGFloat((object?["h"] as? Double) ?? Double(Self.minHeight))
        let scaled = rawH * (Self.captureWidth / max(pageW, 1))
        let height = min(Self.maxHeight, max(Self.minHeight, scaled))
        webView.frame.size = CGSize(width: Self.captureWidth, height: height)
        let config = WKSnapshotConfiguration()
        config.rect = CGRect(x: 0, y: 0, width: Self.captureWidth, height: height)
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            Task { @MainActor in
                self?.finish(image)
            }
        }
    }
}

struct PreviewCaptureHost: UIViewRepresentable {
    func makeUIView(context: Context) -> OffscreenWebHost {
        let host = OffscreenWebHost()
        host.isUserInteractionEnabled = false
        return host
    }

    func updateUIView(_ uiView: OffscreenWebHost, context: Context) {}
}

final class OffscreenWebHost: UIView {
    private let web = WKWebView(
        frame: CGRect(x: -4000, y: 0, width: PreviewCaptureCenter.captureWidth, height: PreviewCaptureCenter.minHeight)
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        web.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { nil }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window else { return }
        if web.superview !== window {
            window.addSubview(web)
        }
        PreviewCaptureCenter.shared.attach(web)
    }
}
