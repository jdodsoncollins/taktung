import Foundation
import Testing
@testable import Taktung

struct ReviewPromptPolicyTests {
    private let first = Date(timeIntervalSince1970: 1_000_000)
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }

    @Test func repeatedChecksOnOneDayCannotTriggerARequest() {
        var p = ReviewPromptPolicy(firstUse: first)
        for _ in 0..<20 { p.recordInspection(at: first.addingTimeInterval(8 * 86_400), calendar: calendar) }
        #expect(p.inspectionDays.count == 1)
        #expect(!p.isEligible(at: first.addingTimeInterval(8 * 86_400)))
    }
    @Test func requiresAWeekAndThreeSeparateDays() {
        var p = ReviewPromptPolicy(firstUse: first)
        for day in [0, 1, 2] { p.recordInspection(at: first.addingTimeInterval(Double(day) * 86_400), calendar: calendar) }
        #expect(!p.isEligible(at: first.addingTimeInterval(2 * 86_400)))
        #expect(p.isEligible(at: first.addingTimeInterval(7 * 86_400)))
    }
    @Test func attemptsHaveAFourMonthCooldownAndOldUseExpires() {
        var p = ReviewPromptPolicy(firstUse: first)
        for day in [0, 1, 7] { p.recordInspection(at: first.addingTimeInterval(Double(day) * 86_400), calendar: calendar) }
        let request = first.addingTimeInterval(7 * 86_400)
        p.recordRequest(at: request)
        #expect(!p.isEligible(at: request.addingTimeInterval(119 * 86_400)))
        #expect(!p.isEligible(at: request.addingTimeInterval(120 * 86_400)))
        for day in [125, 126, 127] { p.recordInspection(at: first.addingTimeInterval(Double(day) * 86_400), calendar: calendar) }
        #expect(p.isEligible(at: request.addingTimeInterval(120 * 86_400)))
    }
    @Test func clockReversalCannotCreateUseOrRequestEligibility() {
        var p = ReviewPromptPolicy(firstUse: first)
        p.recordInspection(at: first.addingTimeInterval(-86_400), calendar: calendar)
        #expect(p.inspectionDays.isEmpty && !p.isEligible(at: first.addingTimeInterval(-1)))
    }
    @Test func stateRoundTripsWithoutIdentityOrSecretsAndStaysBounded() throws {
        var p = ReviewPromptPolicy(firstUse: first)
        for day in 0..<400 { p.recordInspection(at: first.addingTimeInterval(Double(day) * 86_400), calendar: calendar) }
        #expect(p.inspectionDays.count <= 90)
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(ReviewPromptPolicy.self, from: data)
        #expect(decoded.inspectionDays == p.inspectionDays)
        #expect(!String(decoding: data, as: UTF8.self).contains("account"))
    }

    @MainActor @Test func twoScenesCanClaimOnlyOneRequestAndFreshInstancesRetainCadence() throws {
        let suite = "review-cadence-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let firstScene = ReviewPromptStore(defaults: preferences)
        for day in [0, 1, 7] { firstScene.recordInspection(at: first.addingTimeInterval(Double(day) * 86_400)) }
        let secondScene = ReviewPromptStore(defaults: preferences)
        let now = first.addingTimeInterval(7 * 86_400)
        #expect(firstScene.isEligible(at: now) && secondScene.isEligible(at: now))
        #expect(firstScene.claimRequest(at: now))
        #expect(!secondScene.claimRequest(at: now))
        #expect(!ReviewPromptStore(defaults: preferences).isEligible(at: now))
    }

    @MainActor @Test func corruptPreferencesStartConservativelyWithoutPrompting() throws {
        let suite = "review-corrupt-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set(Data("invalid".utf8), forKey: ReviewPromptPolicy.storageKey)
        let store = ReviewPromptStore(defaults: preferences)
        #expect(!store.claimRequest(at: first))
        store.recordInspection(at: first)
        #expect(!store.isEligible(at: first.addingTimeInterval(8 * 86_400)))
    }
}
