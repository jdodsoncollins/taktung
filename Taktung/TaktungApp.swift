import SwiftUI
import CoreSpotlight

@main
struct TaktungApp: App {
    @State private var session = AppSession()
    @State private var tipStore = TipStore()
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(tipStore)
                .task { tipStore.startTransactionListener() }
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
                    session.openSpotlightItem(identifier: identifier)
                }
                .preferredColorScheme(appearance.colorScheme)
                .tint(Palette.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { session.refreshModelAvailability() }
                    else { Task { await session.flushHistory() } }
                }
        }
    }
}
