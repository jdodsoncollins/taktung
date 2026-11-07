import CoreGraphics
import Testing
@testable import Taktung

struct AdaptiveWorkspaceLayoutTests {
    @Test func tallRegularWidthScreensUseOneReadableColumn() {
        // iPad mini and iPad Pro held upright: stacked panes would halve each scroll area.
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: true, size: CGSize(width: 744, height: 1133), foldActive: false) == .oneColumn)
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: true, size: CGSize(width: 834, height: 1210), foldActive: false) == .oneColumn)
    }

    @Test func wideRegularWidthScreensPlacePanesSideBySide() {
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: true, size: CGSize(width: 1210, height: 834), foldActive: false) == .twoPanes)
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: true, size: CGSize(width: 956, height: 440), foldActive: false) == .twoPanes)
    }

    @Test func compactWidthStaysOneColumnUnlessAFoldDividesTheSpace() {
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: false, size: CGSize(width: 402, height: 874), foldActive: false) == .oneColumn)
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: false, size: CGSize(width: 874, height: 402), foldActive: false) == .oneColumn)
        #expect(AdaptiveWorkspaceLayout.resolve(regularWidth: true, size: CGSize(width: 700, height: 900), foldActive: true) == .twoPanes)
    }
}
