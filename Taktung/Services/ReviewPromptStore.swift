import Foundation

/// Main-actor claims serialize request attempts across app windows.
@MainActor
final class ReviewPromptStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func recordInspection(at now: Date = Date()) {
        var policy = load(at: now)
        policy.recordInspection(at: now)
        _ = save(policy)
    }

    func isEligible(at now: Date = Date()) -> Bool { load(at: now).isEligible(at: now) }

    func claimRequest(at now: Date = Date()) -> Bool {
        // Read again after any UI delay; another scene may already have claimed it.
        var policy = load(at: now)
        guard policy.isEligible(at: now) else { return false }
        policy.recordRequest(at: now)
        return save(policy)
    }

    private func load(at now: Date) -> ReviewPromptPolicy {
        guard let data = defaults.data(forKey: ReviewPromptPolicy.storageKey), data.count <= 4_096,
              let policy = try? JSONDecoder().decode(ReviewPromptPolicy.self, from: data) else {
            return ReviewPromptPolicy(firstUse: now)
        }
        return policy
    }

    private func save(_ policy: ReviewPromptPolicy) -> Bool {
        guard let data = try? JSONEncoder().encode(policy) else { return false }
        defaults.set(data, forKey: ReviewPromptPolicy.storageKey)
        return true
    }
}
