import SwiftUI
import UIKit

struct RootView: View {
    @Environment(AppSession.self) private var session
    @State private var section: TaktSection = .home

    var body: some View {
        @Bindable var session = session
        TabView(selection: $section) {
            Tab("Home", systemImage: "house.fill", value: TaktSection.home) {
                NavigationStack { HomeView() }
            }
            Tab("Deploys", systemImage: "arrow.up.right", value: TaktSection.deploys) {
                NavigationStack { DeploymentsView() }
            }
            Tab("Activity", systemImage: "clock", value: TaktSection.activity) {
                NavigationStack { ActivityView() }
            }
            if session.showsSearch {
                Tab("Search", systemImage: "sparkle", value: TaktSection.search) {
                    NavigationStack { SearchView() }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onReceive(NotificationCenter.default.publisher(for: .taktungOpenSection)) { note in
            guard let raw = note.object as? String, let next = TaktSection(rawValue: raw) else { return }
            section = next == .search && !session.showsSearch ? .home : next
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .background(WindowCanvas())
        .background(PreviewCaptureHost())
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

/// Paints the UIKit window. SwiftUI backgrounds stop at the scroll content, so the sides stay black.
private struct WindowCanvas: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = CanvasView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? CanvasView)?.paint()
    }

    private final class CanvasView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            paint()
        }

        func paint() {
            window?.backgroundColor = UIColor(red: 12 / 255, green: 9 / 255, blue: 8 / 255, alpha: 1)
        }
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
