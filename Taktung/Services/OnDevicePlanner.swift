import Foundation
import OSLog

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
        guard isAvailable, let prompt = BriefModelPolicy.prompt(context) else { return nil }
        let started = ContinuousClock.now
        do {
            let model = SystemLanguageModel.default
            // A fresh session prevents repeated checks from accumulating history.
            let inputTokens = try await model.tokenCount(for: prompt)
            let instructionTokens = try await model.tokenCount(for: Instructions(BriefModelPolicy.instructions))
            guard inputTokens + instructionTokens + BriefModelPolicy.responseTokens + 128 < model.contextSize,
                  !Task.isCancelled else { return nil }
            let session = LanguageModelSession(model: model, instructions: BriefModelPolicy.instructions)
            let response = try await session.respond(to: prompt, options: GenerationOptions(
                samplingMode: .greedy, maximumResponseTokens: BriefModelPolicy.responseTokens))
            guard !Task.isCancelled else { return nil }
            let accepted = BriefModelPolicy.accept(response.content)
            #if DEBUG
            let duration = started.duration(to: .now).components
            let milliseconds = duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000
            Logger(subsystem: AppConfig.bundleID, category: "OnDeviceBrief").info(
                "Brief input=\(inputTokens + instructionTokens) output=\(response.usage.output.totalTokenCount) context=\(model.contextSize) ms=\(milliseconds) accepted=\(accepted != nil)")
            #endif
            return accepted
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
