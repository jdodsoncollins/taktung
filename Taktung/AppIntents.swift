import AppIntents
import Foundation

enum TaktSection: String, Hashable, Sendable {
    case home, deploys, activity, search
}

extension Notification.Name {
    static let taktungOpenSection = Notification.Name("taktung.openSection")
}

enum TaktRouter {
    static func open(_ section: TaktSection) {
        NotificationCenter.default.post(name: .taktungOpenSection, object: section.rawValue)
    }
}

struct OpenHomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Home"
    static let description = IntentDescription("Opens Taktung on Home.")
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktRouter.open(.home)
        return .result()
    }
}

struct OpenDeploymentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Deployments"
    static let description = IntentDescription("Opens the deployment list.")
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktRouter.open(.deploys)
        return .result()
    }
}

struct OpenActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Activity"
    static let description = IntentDescription("Opens local activity history.")
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        TaktRouter.open(.activity)
        return .result()
    }
}

struct TaktungShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenHomeIntent(),
            phrases: ["Open \(.applicationName)", "Show \(.applicationName) home"],
            shortTitle: "Home",
            systemImageName: "house"
        )
        AppShortcut(
            intent: OpenDeploymentsIntent(),
            phrases: ["Show \(.applicationName) deployments", "Open deploys in \(.applicationName)"],
            shortTitle: "Deploys",
            systemImageName: "arrow.up.right"
        )
        AppShortcut(
            intent: OpenActivityIntent(),
            phrases: ["Show \(.applicationName) activity"],
            shortTitle: "Activity",
            systemImageName: "clock"
        )
    }
}
