import SwiftUI

@main
struct TaktungApp: App {
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
                .task { await session.bootstrap() }
        }
    }
}
