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

    /// One sentence explaining a failed build from a bounded, redacted excerpt.
    /// Nil when unavailable or unsafe; the key log lines still show on every device.
    static func explainBuildFailure(_ excerpt: BuildFailureExcerpt) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable, let prompt = BuildFailurePolicy.prompt(excerpt) else { return nil }
        do {
            let model = SystemLanguageModel.default
            let inputTokens = try await model.tokenCount(for: prompt)
            let instructionTokens = try await model.tokenCount(for: Instructions(BuildFailurePolicy.instructions))
            guard inputTokens + instructionTokens + BuildFailurePolicy.responseTokens + 128 < model.contextSize,
                  !Task.isCancelled else { return nil }
            // A fresh session per explanation; no history carries between builds.
            let session = LanguageModelSession(model: model, instructions: BuildFailurePolicy.instructions)
            let response = try await session.respond(to: prompt, options: GenerationOptions(
                samplingMode: .greedy, maximumResponseTokens: BuildFailurePolicy.responseTokens))
            guard !Task.isCancelled else { return nil }
            return response.content
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// A short summary of a bounded, redacted Field Log selection. Nil when
    /// unavailable; the deterministic counts and entry list still show.
    static func summarizeFieldLog(prompt: String) async -> String? {
        #if canImport(FoundationModels)
        guard isAvailable, prompt.utf8.count <= FieldLogDigestPolicy.maximumBytes + 256 else { return nil }
        do {
            let model = SystemLanguageModel.default
            let inputTokens = try await model.tokenCount(for: prompt)
            let instructionTokens = try await model.tokenCount(for: Instructions(FieldLogDigestPolicy.instructions))
            guard inputTokens + instructionTokens + FieldLogDigestPolicy.responseTokens + 128 < model.contextSize,
                  !Task.isCancelled else { return nil }
            let session = LanguageModelSession(model: model, instructions: FieldLogDigestPolicy.instructions)
            let response = try await session.respond(to: prompt, options: GenerationOptions(
                samplingMode: .greedy, maximumResponseTokens: FieldLogDigestPolicy.responseTokens))
            guard !Task.isCancelled else { return nil }
            return response.content
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Reads a Field Log request into filters. The prompt holds the request and
    /// loaded site names only; journal records never reach the model.
    static func planFieldLogSearch(query: String, siteNames: [String]) async -> FieldLogModelDraft? {
        #if canImport(FoundationModels)
        guard isAvailable, let prompt = FieldLogModelPolicy.prompt(query, siteNames: siteNames) else { return nil }
        do {
            let model = SystemLanguageModel.default
            let inputTokens = try await model.tokenCount(for: prompt)
            let instructionTokens = try await model.tokenCount(for: Instructions(FieldLogModelPolicy.instructions))
            guard inputTokens + instructionTokens + FieldLogModelPolicy.responseTokens + 1_024 < model.contextSize,
                  !Task.isCancelled else { return nil }
            let session = LanguageModelSession(model: model, instructions: FieldLogModelPolicy.instructions)
            let response = try await session.respond(to: prompt, generating: FieldLogPlanGeneration.self, options: GenerationOptions(
                samplingMode: .greedy, maximumResponseTokens: FieldLogModelPolicy.responseTokens))
            guard !Task.isCancelled else { return nil }
            return response.content.draft
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
private struct FieldLogPlanGeneration {
    @Generable enum Category { case notes, checks, comparisons, actions }
    @Generable enum Outcome { case succeeded, failed, canceled }
    @Generable enum Timeframe { case any, today, yesterday, thisWeek, thisMonth, lastHours, lastDays }

    @Guide(description: "Kinds of Field Log entries the request asks for; empty for any kind", .maximumCount(4))
    var categories: [Category]
    @Guide(description: "Outcomes the request asks for; empty for any outcome", .maximumCount(3))
    var outcomes: [Outcome]
    @Guide(description: "Time span the request names")
    var timeframe: Timeframe
    @Guide(description: "Number of hours for lastHours or days for lastDays; 0 otherwise", .range(0...365))
    var amount: Int
    @Guide(description: "A loaded site name copied exactly from the request, or empty")
    var siteName: String
    @Guide(description: "The subject to find, copied exactly from the request, or empty")
    var text: String

    var draft: FieldLogModelDraft {
        let timeframe: SearchModelDraft.Timeframe = switch self.timeframe {
            case .any: .any
            case .today: .today
            case .yesterday: .yesterday
            case .thisWeek: .thisWeek
            case .thisMonth: .thisMonth
            case .lastHours: .lastHours
            case .lastDays: .lastDays
        }
        return FieldLogModelDraft(
            categories: categories.map {
                switch $0 {
                case .notes: .notes
                case .checks: .checks
                case .comparisons: .comparisons
                case .actions: .actions
                }
            },
            outcomes: outcomes.map {
                switch $0 {
                case .succeeded: .succeeded
                case .failed: .failed
                case .canceled: .canceled
                }
            },
            timeframe: timeframe, amount: amount, siteName: siteName, text: text)
    }
}
#endif

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
