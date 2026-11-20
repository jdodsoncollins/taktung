import UIKit
import WebKit
import Testing
@testable import Taktung

/// Serves one HTML document at `/` and never answers anything else, like a slow analytics
/// request, third-party frame, render-blocking script or below-the-fold image.
private final class StallingSite: NSObject, WKURLSchemeHandler {
    let html: String
    init(html: String) { self.html = html }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, url.path.isEmpty || url.path == "/" else { return }
        urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                                 headerFields: ["Content-Type": "text/html; charset=utf-8"])!)
        urlSchemeTask.didReceive(Data(html.utf8))
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}

@MainActor
private func captureHost() throws -> UIView {
    let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = try #require(scene.windows.first { $0.isKeyWindow } ?? scene.windows.first)
    let host = UIView(frame: window.bounds)
    host.isUserInteractionEnabled = false
    window.addSubview(host)
    return host
}

@MainActor
private func capture(_ html: String, timeout: Duration) async throws -> Data {
    let host = try captureHost()
    defer { host.removeFromSuperview() }
    let configuration = WKWebViewConfiguration()
    configuration.setURLSchemeHandler(StallingSite(html: html), forURLScheme: "taktung-stall")
    let job = VisualPageCapture(url: URL(string: "taktung-stall://site/")!, configuration: configuration,
                                timeout: timeout, settleBudgetMilliseconds: 300)
    return try await job.capture(in: host)
}

struct VisualPageCaptureTests {
    @Test @MainActor func capturesTheVisiblePageWithoutWaitingForEveryResource() async throws {
        // The window load event never fires: an on-screen image, a below-the-fold image and a frame all stall.
        let html = """
            <html><body style="margin:0;background:#cc713b">
            <h1>Visible page</h1>
            <img src="/hero.png" width="200" height="100">
            <img src="/footer.png" width="200" height="100" style="position:absolute;top:3000px">
            <iframe src="/frame.html"></iframe>
            </body></html>
            """
        let started = ContinuousClock.now
        let png = try await capture(html, timeout: .seconds(10))
        #expect(UIImage(data: png) != nil)
        #expect(ContinuousClock.now - started < .seconds(8))
    }

    @Test @MainActor func reportsATimeoutWhenTheDocumentNeverBecomesReady() async throws {
        // A parser-blocking script that never arrives keeps the document loading.
        let html = "<html><head><script src=\"/blocking.js\"></script></head><body>Never parsed</body></html>"
        do {
            _ = try await capture(html, timeout: .seconds(2))
            Issue.record("A document that never parses must not produce a capture.")
        } catch let error as VisualComparisonError {
            guard case .timedOut = error else {
                Issue.record("Expected a timeout, got \(error)")
                return
            }
        }
    }
}
