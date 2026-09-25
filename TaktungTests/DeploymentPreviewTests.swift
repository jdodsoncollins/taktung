import Testing
@testable import Taktung

struct DeploymentPreviewTests {
    @Test func probesOnlyReadySites() {
        #expect(shouldProbeDeploymentPreview(state: .ready, url: "example.vercel.app"))
        #expect(!shouldProbeDeploymentPreview(state: .error, url: "https://example.vercel.app"))
        #expect(!shouldProbeDeploymentPreview(state: .building, url: "https://example.vercel.app"))
        #expect(!shouldProbeDeploymentPreview(state: .ready, url: nil))
        #expect(!shouldProbeDeploymentPreview(state: .ready, url: "https://vercel.com/login"))
    }

    @Test func rejectsVercelLoginWalls() {
        #expect(isUnusablePreviewLocation("https://vercel.com/login"))
        #expect(isUnusablePreviewLocation("https://example.vercel.app/sso-api", title: "Authentication Required"))
        #expect(!isUnusablePreviewLocation("https://www.jeremycollins.net"))
    }

    @Test @MainActor func captureWebViewStaysOffscreen() {
        let parked = PreviewCaptureCenter.offscreenFrame(height: 1600)
        #expect(parked.minX < 0)
        #expect(parked.maxX <= 0)
        #expect(parked.width == PreviewCaptureCenter.captureWidth)
        #expect(parked.height == 1600)
    }

    @Test func absoluteURLAddsScheme() {
        #expect(absoluteDeploymentURL("example.vercel.app") == "https://example.vercel.app")
        #expect(absoluteDeploymentURL("https://example.vercel.app") == "https://example.vercel.app")
        #expect(absoluteDeploymentURL("  ") == nil)
    }
}
