import SwiftUI

struct RootView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        @Bindable var session = session
        TabView {
            Tab("Home", systemImage: "house.fill") {
                NavigationStack { HomeView() }
            }
            Tab("Deploys", systemImage: "arrow.up.right") {
                NavigationStack { DeploymentsView() }
            }
            Tab("Activity", systemImage: "clock") {
                NavigationStack { ActivityView() }
            }
            if session.showsSearch {
                Tab("Search", systemImage: "sparkle") {
                    NavigationStack { SearchView() }
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIDs.root)
        .sheet(isPresented: $session.settingsOpen) {
            NavigationStack { SettingsView() }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $session.sitePickerOpen) {
            NavigationStack { SitePickerView() }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            session.pendingMutation?.title ?? "Confirm",
            isPresented: Binding(
                get: { session.pendingMutation != nil },
                set: { if !$0 { session.pendingMutation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Confirm \(session.pendingMutation?.title ?? "")", role: .destructive) {
                Task { await session.confirmPendingMutation() }
            }
            Button("Cancel", role: .cancel) {
                session.pendingMutation = nil
            }
        } message: {
            Text(session.pendingMutation?.message ?? "This action requires confirmation.")
        }
        .background(Palette.background.ignoresSafeArea())
    }
}

struct ChromeToolbar: ToolbarContent {
    @Environment(AppSession.self) private var session
    var showRefresh: Bool = true

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                session.settingsOpen = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier(AccessibilityIDs.tabSettings)
        }
        ToolbarItem(placement: .principal) {
            Button {
                session.sitePickerOpen = true
            } label: {
                HStack(spacing: 6) {
                    Text(principalTitle)
                        .font(MonoFont.body(13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .accessibilityIdentifier(AccessibilityIDs.siteTitle)
            .accessibilityLabel(principalTitle)
        }
        if showRefresh {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await session.refreshProjects() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
                .disabled(session.isBusy)
            }
        }
    }

    private var principalTitle: String {
        if let project = session.selectedProject {
            return siteTitle(project).uppercased()
        }
        return session.connection.isConnected ? "PICK A SITE" : "TAKTUNG"
    }
}
