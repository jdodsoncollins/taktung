import Testing
@testable import Taktung

struct SiteScopeTests {
    @Test func titlePrefersHost() {
        let project = buildDemoProjects().first { $0.id == DemoIDs.portfolio }!
        #expect(siteTitle(project) == "example-portfolio.app")
        #expect(siteStampGit(project) == "7f3a21c")
        #expect(siteStampProd(project) == "main")
        let clear = siteClearWord(project)
        #expect(clear.label == "ALL CLEAR")
        #expect(clear.tone == .ready)
    }

    @Test func rankPutsAttentionFirst() {
        var projects = buildDemoProjects()
        projects[1].needsAttention = true
        projects[1].attentionReason = .recentFailure
        let ranked = rankSites(projects)
        #expect(ranked.first?.needsAttention == true)
    }
}
