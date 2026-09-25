import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum OnDevicePlanner {
    /// True when Apple Intelligence / Foundation Models can run on this device.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return true
            default:
                return false
            }
        }
        #endif
        return false
    }

    /// One short ops sentence from the on-device model. Nil when the model is
    /// unavailable or the text looks like a secret. Heuristic briefs still run.
    static func brief(context: String) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable, #available(iOS 26.0, *) else { return nil }
        if containsSecretLike(context) { return nil }
        do {
            let session = LanguageModelSession(
                instructions: "You write one sentence for a Vercel operator. Do not invent environment values, tokens, or hostnames that were not provided."
            )
            let response = try await session.respond(to: context)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !containsSecretLike(text) else { return nil }
            return text
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
