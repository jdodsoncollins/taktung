import AppIntents
import SwiftUI

struct OpenHomeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Home"
    static let description = IntentDescription("Opens Taktung on Home.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OpenDeploymentsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Deployments"
    static let description = IntentDescription("Opens Taktung on Deployments.")
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct TaktungShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenHomeIntent(),
            phrases: ["Open \(.applicationName) home"],
            shortTitle: "Home",
            systemImageName: "house"
        )
        AppShortcut(
            intent: OpenDeploymentsIntent(),
            phrases: ["Open \(.applicationName) deployments"],
            shortTitle: "Deploys",
            systemImageName: "arrow.up.right"
        )
    }
}
