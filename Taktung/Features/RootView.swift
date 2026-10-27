import SwiftUI
import UIKit
import StoreKit

struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    private let reviewStore = ReviewPromptStore()
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @State private var section: TaktSection = .home
    @State private var navigationInvocations: [TaktSection: UUID] = [:]
    private let router = TaktRouter.shared

    var body: some View {
        @Bindable var session = session
        TabView(selection: $section) {
            Tab("Home", systemImage: "house.fill", value: TaktSection.home) {
                NavigationStack { HomeView() }
                    .id(SiteNavigationScope(evidence: session.evidenceScope, projectID: session.selectedProjectId,
                                            invocationID: navigationInvocations[.home]))
            }
            Tab("Deploys", systemImage: "arrow.up.right", value: TaktSection.deploys) {
                NavigationStack { DeploymentsView() }
                    .id(SiteNavigationScope(evidence: session.evidenceScope, projectID: session.selectedProjectId,
                                            invocationID: navigationInvocations[.deploys]))
            }
            Tab("Activity", systemImage: "clock", value: TaktSection.activity) {
                NavigationStack { ActivityView() }
                    .id(SiteNavigationScope(evidence: session.evidenceScope, projectID: nil,
                                            invocationID: navigationInvocations[.activity]))
            }
            if session.showsSearch {
                Tab("Search", systemImage: "sparkle", value: TaktSection.search) {
                    NavigationStack { SearchView() }
                        .id(SiteNavigationScope(evidence: session.evidenceScope, projectID: session.selectedProjectId,
                                                invocationID: navigationInvocations[.search]))
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onOpenURL { url in
            if let route = ShortcutRoute.from(url) { router.enqueue(route) }
        }
        .task { await session.bootstrap(); await handlePendingRoute() }
        .task(id: session.reviewOpportunity?.id) { await considerReviewPrompt() }
        .onChange(of: router.pending?.id) { _, _ in Task { await handlePendingRoute() } }
        .onChange(of: session.isRehydrating) { _, ready in
            if !ready { Task { await handlePendingRoute() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await handlePendingRoute() } }
        }
        .onChange(of: session.showsSearch) { _, available in
            if !available, section == .search { section = .home }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .background(WindowCanvas())
        .background(PreviewCaptureHost())
        .background(VisualCaptureHost())
        .accessibilityIdentifier(AccessibilityIDs.root)
        .sheet(isPresented: $session.settingsOpen) {
            NavigationStack { SettingsView() }
                .modifier(TipPurchaseNotice())
                .preferredColorScheme(appearance.colorScheme ?? colorScheme)
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
                // Capture before SwiftUI dismisses the dialog and clears its binding.
                guard let pending = session.pendingMutation else { return }
                session.pendingMutation = nil
                Task { await session.confirmMutation(pending) }
            }
            Button("Cancel", role: .cancel) {
                session.pendingMutation = nil
            }
        } message: {
            Text(session.pendingMutation?.message ?? "This action requires confirmation.")
        }
        .background(Palette.background.ignoresSafeArea())
    }

    private func handlePendingRoute() async {
        guard scenePhase == .active, !session.isRehydrating,
              let route = router.takePending() else { return }
        // Change the visible tab before optional generation starts.
        section = route.section == .search && !session.showsSearch ? .home : route.section
        navigationInvocations[section] = route.id
        await session.handleShortcutRoute(route)
    }

    private func considerReviewPrompt() async {
        guard let opportunity = session.reviewOpportunity, session.allowsReviewRequests else { return }
        reviewStore.recordInspection()
        guard opportunity.mayPrompt, reviewStore.isEligible() else { return }
        do { try await Task.sleep(for: .seconds(3)) } catch { return }
        guard !Task.isCancelled, scenePhase == .active, section == .home,
              session.reviewOpportunity?.id == opportunity.id,
              session.evidenceScope == opportunity.scope, session.selectedProjectId == opportunity.projectID,
              !session.settingsOpen, !session.sitePickerOpen, session.pendingMutation == nil,
              !session.isBusy, !session.isGeneratingBrief, router.pending == nil else { return }
        #if !DEBUG
        // StoreKit controls whether a prompt is actually presented.
        guard reviewStore.claimRequest() else { return }
        requestReview()
        #endif
    }
}

private struct SiteNavigationScope: Hashable {
    var evidence: EvidenceScope?
    var projectID: ProjectID?
    var invocationID: UUID?
}

/// Paints the UIKit window. SwiftUI backgrounds stop at the scroll content, so the sides stay black.
private struct WindowCanvas: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    func makeUIView(context: Context) -> UIView {
        let view = CanvasView()
        view.style = colorScheme == .dark ? .dark : .light
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let view = uiView as? CanvasView else { return }
        view.style = colorScheme == .dark ? .dark : .light
        view.paint()
    }

    private final class CanvasView: UIView {
        var style: UIUserInterfaceStyle = .light
        override func didMoveToWindow() {
            super.didMoveToWindow()
            paint()
        }

        func paint() {
            window?.backgroundColor = Palette.canvas.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        }
    }
}

struct ChromeToolbar: ToolbarContent {
    @Environment(AppSession.self) private var session
    var showRefresh: Bool = true

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") {
                session.settingsOpen = true
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier(AccessibilityIDs.tabSettings)
        }
        ToolbarItem(placement: .principal) {
            // The site name carries essential scope; keep it legible above the content.
            SiteTitleButton(title: principalTitle) { session.sitePickerOpen = true }
        }
        if showRefresh {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await session.refreshProjects() }
                }
                .accessibilityLabel("Refresh")
                .disabled(session.isBusy)
            }
        }
    }

    private var principalTitle: String {
        if let project = session.selectedProject {
            return siteTitle(project)
        }
        return session.connection.isConnected ? "Choose a site" : "Taktung"
    }
}

private struct SiteTitleButton: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
            }.frame(maxWidth: sizeClass == .compact ? 210 : 360)
        }
        .accessibilityIdentifier(AccessibilityIDs.siteTitle)
        .accessibilityLabel(title)
    }
}
