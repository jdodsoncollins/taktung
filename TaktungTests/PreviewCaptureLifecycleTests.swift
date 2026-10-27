import UIKit
import WebKit
import Testing
@testable import Taktung

@MainActor
private final class ControlledPreviewWebView: WKWebView {
    var navigations: [WKNavigation] = []
    private var loadObserver: (Int, CheckedContinuation<Void, Never>)?
    override func load(_ request: URLRequest) -> WKNavigation? {
        let navigation = super.loadHTMLString("<html><body style='background:#cc713b;height:640px'>Captured second page</body></html>", baseURL: request.url)!
        navigations.append(navigation)
        if let (count, observer) = loadObserver, navigations.count >= count {
            loadObserver = nil
            observer.resume()
        }
        return navigation
    }
    func untilLoads(_ count: Int) async {
        if navigations.count >= count { return }
        await withCheckedContinuation { loadObserver = (count, $0) }
    }
}

struct PreviewCaptureLifecycleTests {
    @Test @MainActor func lateFailureFromFirstPageCannotFailTheNextCapture() async throws {
        let center = PreviewCaptureCenter()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIViewController()
        let webView = ControlledPreviewWebView(frame: .zero, configuration: WKWebViewConfiguration())
        window.addSubview(webView)
        window.isHidden = false
        defer { window.isHidden = true; webView.removeFromSuperview() }
        center.attach(webView)
        let first = Task { await center.image(for: "https://first.example/") }
        await webView.untilLoads(1)
        let firstNavigation = webView.navigations[0]
        center.webView(webView, didFail: firstNavigation, withError: URLError(.cancelled))
        #expect(await first.value == nil)
        let second = Task { await center.image(for: "https://second.example/") }
        await webView.untilLoads(2)
        center.webView(webView, didFailProvisionalNavigation: firstNavigation, withError: URLError(.cancelled))
        let captured = await second.value
        #expect(captured != nil)
        #expect(center.cachedImage(for: "https://second.example/") != nil)
        #expect(center.cachedImage(for: "https://first.example/") == nil)
    }
}
