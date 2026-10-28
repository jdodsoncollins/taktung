import Foundation
import Testing
@testable import Taktung

struct SinceLastVisitTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let now = Date(timeIntervalSince1970: 1_793_145_600) // 2026-10-28 00:00 UTC

    private func deploy(_ id: String, _ state: DeploymentState, minutesAgo: Double, target: DeploymentTarget? = .preview,
                        message: String = "Fix analytics totals") -> VercelDeploymentSummary {
        VercelDeploymentSummary(id: id, name: "site", state: state, target: target,
                                createdAt: (now.timeIntervalSince1970 - minutesAgo * 60) * 1000,
                                meta: GitMeta(githubCommitRef: "feature/login", githubCommitSha: "3f2a91c0d4e5f60718293a4b5c6d7e8f90a1b2c3",
                                              githubCommitMessage: message))
    }

    private func mark(hoursAgo: Double, production: DeploymentID?) -> SiteVisitMark {
        let seen = now.addingTimeInterval(-hoursAgo * 3_600)
        return SiteVisitMark(seenAt: seen, newestDeploymentAt: seen.timeIntervalSince1970 * 1000, productionDeploymentID: production)
    }

    @Test func countsOnlyDeploymentsNewerThanTheMark() {
        let prod = deploy("prod", .ready, minutesAgo: 300, target: .production)
        let list = [deploy("a", .ready, minutesAgo: 10), deploy("b", .error, minutesAgo: 20),
                    deploy("c", .building, minutesAgo: 30), prod]
        let visit = summarizeSinceLastVisit(projectID: "p", mark: mark(hoursAgo: 2, production: "prod"),
                                            deployments: list, production: prod, now: now, calendar: calendar)
        #expect(visit.newDeployments.map(\.id) == ["a", "b", "c"])
        #expect(visit.failed.map(\.id) == ["b"])
        #expect(visit.productionNow == nil)
        #expect(visit.summary.hasPrefix("3 new deployments since "))
        #expect(visit.summary.hasSuffix(": 1 ready, 1 failed, 1 building."))
        #expect(!visit.isQuiet)
    }

    @Test func reportsAProductionChangeEvenWithoutNewDeployments() {
        let promoted = deploy("older", .ready, minutesAgo: 600, target: .production, message: "Repair Web Analytics")
        let visit = summarizeSinceLastVisit(projectID: "p", mark: mark(hoursAgo: 2, production: "previous"),
                                            deployments: [promoted], production: promoted, now: now, calendar: calendar)
        #expect(visit.newDeployments.isEmpty)
        #expect(visit.productionNow?.id == "older")
        #expect(visit.summary == "Production now runs “Repair Web Analytics” (3f2a91c).")
    }

    @Test func quietVisitsSaySoAndAFullPageIsALowerBound() {
        let old = deploy("old", .ready, minutesAgo: 600, target: .production)
        let quiet = summarizeSinceLastVisit(projectID: "p", mark: mark(hoursAgo: 2, production: "old"),
                                            deployments: [old], production: old, now: now, calendar: calendar)
        #expect(quiet.isQuiet)
        #expect(quiet.summary.hasPrefix("Nothing new since "))

        let page = (0..<visitDeploymentWindow).map { deploy("d\($0)", .ready, minutesAgo: Double($0 + 1)) }
        let busy = summarizeSinceLastVisit(projectID: "p", mark: mark(hoursAgo: 2, production: nil),
                                           deployments: page, production: nil, now: now, calendar: calendar)
        #expect(busy.atLeast)
        #expect(busy.summary.hasPrefix("At least 30 new deployments since "))
        #expect(busy.summary.hasSuffix(", all ready."))
    }

    @Test func aDeploymentSeenBeforeIsNeverNewEvenIfItsTimeMoves() {
        let rebuilt = deploy("same", .ready, minutesAgo: 1)
        var seen = mark(hoursAgo: 1, production: nil)
        seen.seenDeploymentIDs = ["same"]
        let visit = summarizeSinceLastVisit(projectID: "p", mark: seen, deployments: [rebuilt], production: nil,
                                            now: now, calendar: calendar)
        #expect(visit.isQuiet)
    }

    @Test func timeLabelsNameTheDay() {
        #expect(visitTimeLabel(now.addingTimeInterval(-3_600), now: now.addingTimeInterval(1), calendar: calendar).hasPrefix("yesterday at "))
        #expect(visitTimeLabel(now.addingTimeInterval(-3 * 86_400), now: now, calendar: calendar).contains(" at "))
        #expect(!visitTimeLabel(now.addingTimeInterval(-20 * 86_400), now: now, calendar: calendar).contains(" at "))
    }

    @Test func modelSentencesMayNotChangeNumbers() {
        let facts = "Site: portfolio\n3 new deployments since 9:14 PM: 2 ready, 1 failed."
        #expect(VisitDigestModelPolicy.accept("Since 9:14 PM, 3 deploys went out and 1 failed.", facts: facts) != nil)
        #expect(VisitDigestModelPolicy.accept("Since 9:14 PM, 4 deploys went out and 1 failed.", facts: facts) == nil)
        #expect(VisitDigestModelPolicy.accept("Since 9:14 PM, five deploys went out.", facts: facts) == nil)
        #expect(VisitDigestModelPolicy.accept("Three deploys\nwent out.", facts: facts) == nil)
    }

    @Test func factsSkipSecretLikeCommitText() {
        let leaked = deploy("x", .error, minutesAgo: 5, message: "Add token vcp_abcdefghijklmnopqrstuvwxyz123456")
        let visit = summarizeSinceLastVisit(projectID: "p", mark: mark(hoursAgo: 1, production: nil),
                                            deployments: [leaked], production: nil, now: now, calendar: calendar)
        #expect(visitDigestFacts(visit, siteName: "portfolio") == nil)
    }
}
