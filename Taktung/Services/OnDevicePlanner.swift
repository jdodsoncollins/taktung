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

    /// Reads a Search request into filters with guided generation. Nil when the
    /// model is unavailable, the request is unsafe to send, or generation fails;
    /// the deterministic rules then stand on their own.
    static func planSearch(query: String, siteNames: [String]) async -> SearchModelDraft? {
        #if canImport(FoundationModels)
        guard isAvailable, let prompt = SearchModelPolicy.prompt(query, siteNames: siteNames) else { return nil }
        let started = ContinuousClock.now
        do {
            let model = SystemLanguageModel.default
            let inputTokens = try await model.tokenCount(for: prompt)
            let instructionTokens = try await model.tokenCount(for: Instructions(SearchModelPolicy.instructions))
            // Leave room for the generated schema as well as the response.
            guard inputTokens + instructionTokens + SearchModelPolicy.responseTokens + 1_024 < model.contextSize,
                  !Task.isCancelled else { return nil }
            let session = LanguageModelSession(model: model, instructions: SearchModelPolicy.instructions)
            let response = try await session.respond(to: prompt, generating: SearchPlanGeneration.self, options: GenerationOptions(
                samplingMode: .greedy, maximumResponseTokens: SearchModelPolicy.responseTokens))
            guard !Task.isCancelled else { return nil }
            #if DEBUG
            let duration = started.duration(to: .now).components
            let milliseconds = duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000
            Logger(subsystem: AppConfig.bundleID, category: "OnDeviceSearch").info(
                "Search plan input=\(inputTokens + instructionTokens) output=\(response.usage.output.totalTokenCount) ms=\(milliseconds)")
            #endif
            return response.content.draft
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// One sentence restating Home's "Since you last looked" facts. Nil when the
    /// model is unavailable or the reply changes a number; the facts then stand.
    static func visitDigest(facts: String) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable, let prompt = BriefModelPolicy.prompt(facts) else { return nil }
        let started = ContinuousClock.now
        do {
            let model = SystemLanguageModel.default
            let inputTokens = try await model.tokenCount(for: prompt)
            let instructionTokens = try await model.tokenCount(for: Instructions(VisitDigestModelPolicy.instructions))
            guard inputTokens + instructionTokens + VisitDigestModelPolicy.responseTokens + 128 < model.contextSize,
                  !Task.isCancelled else { return nil }
            let session = LanguageModelSession(model: model, instructions: VisitDigestModelPolicy.instructions)
            let response = try await session.respond(to: prompt, options: GenerationOptions(
                samplingMode: .greedy, maximumResponseTokens: VisitDigestModelPolicy.responseTokens))
            guard !Task.isCancelled else { return nil }
            let accepted = VisitDigestModelPolicy.accept(response.content, facts: facts)
            #if DEBUG
            let duration = started.duration(to: .now).components
            let milliseconds = duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000
            Logger(subsystem: AppConfig.bundleID, category: "OnDeviceVisit").info(
                "Visit digest input=\(inputTokens + instructionTokens) output=\(response.usage.output.totalTokenCount) ms=\(milliseconds) accepted=\(accepted != nil)")
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

#if canImport(FoundationModels)
@Generable
private struct SearchPlanGeneration {
    @Generable enum Intent { case deployments, site, environmentVariables, unclear }
    @Generable enum Outcome { case ready, failed, canceled, building }
    @Generable enum Environment { case any, production, preview }
    @Generable enum Timeframe { case any, today, yesterday, thisWeek, thisMonth, lastHours, lastDays }

    @Guide(description: "deployments to list the selected site's deployments, site to find a loaded site by name, environmentVariables to check environment variable names, unclear otherwise")
    var intent: Intent
    @Guide(description: "Deployment outcomes the request asks for; empty for any outcome", .maximumCount(4))
    var outcomes: [Outcome]
    @Guide(description: "Deployment environment the request names")
    var environment: Environment
    @Guide(description: "Git branch copied exactly from the request, or empty")
    var branch: String
    @Guide(description: "Time span the request names")
    var timeframe: Timeframe
    @Guide(description: "Number of hours for lastHours or days for lastDays; 0 otherwise", .range(0...365))
    var amount: Int
    @Guide(description: "How many deployments the request asks to see; 0 when it does not say", .range(0...100))
    var count: Int
    @Guide(description: "Words to find in commit messages, copied exactly from the request, or empty")
    var commitText: String
    @Guide(description: "A loaded site name copied exactly from the request, or empty")
    var siteName: String

    var draft: SearchModelDraft {
        let intent: SearchModelDraft.Intent = switch self.intent {
            case .deployments: .deployments
            case .site: .site
            case .environmentVariables: .environmentVariables
            case .unclear: .unclear
        }
        let outcomes: [SearchModelDraft.Outcome] = self.outcomes.map {
            switch $0 {
            case .ready: .ready
            case .failed: .failed
            case .canceled: .canceled
            case .building: .building
            }
        }
        let environment: SearchModelDraft.Environment = switch self.environment {
            case .any: .any
            case .production: .production
            case .preview: .preview
        }
        let timeframe: SearchModelDraft.Timeframe = switch self.timeframe {
            case .any: .any
            case .today: .today
            case .yesterday: .yesterday
            case .thisWeek: .thisWeek
            case .thisMonth: .thisMonth
            case .lastHours: .lastHours
            case .lastDays: .lastDays
        }
        return SearchModelDraft(intent: intent, outcomes: outcomes, environment: environment, branch: branch,
                                timeframe: timeframe, amount: amount, count: count, commitText: commitText, siteName: siteName)
    }
}
#endif
