import SwiftUI

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
                .preferredColorScheme(appearance.colorScheme)
                .tint(Palette.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { session.refreshModelAvailability() }
                    else { Task { await session.flushHistory() } }
                }
        }
    }
}
