import SwiftUI

struct ActivityView: View {
    @Environment(AppSession.self) private var session
    @State private var scope: Scope = .site
    @State private var confirmClear = false

    enum Scope { case site, all }

    var body: some View {
        let items: [ActivityItem] = {
            if scope != .site, session.selectedProject == nil { return session.recentActivity }
            guard scope == .site, let id = session.selectedProject?.id else {
                return session.recentActivity
            }
            return session.recentActivity.filter { $0.projectId == nil || $0.projectId == id }
        }()

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if session.selectedProject != nil {
                    HStack(spacing: Spacing.sm) {
                        FilterChip(label: "This site", selected: scope == .site) { scope = .site }
                        FilterChip(label: "All", selected: scope == .all) { scope = .all }
                    }
                } else {
                    Text("Choose a site to filter this list, or use All.")
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                PrimaryButton(
                    title: "Clear activity",
                    role: .danger,
                    disabled: session.recentActivity.isEmpty
                ) {
                    confirmClear = true
                }
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            StateWord(label: item.outcome.rawValue, tone: outcomeTone(item.outcome))
                            Spacer()
                            Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(MonoFont.body(11))
                                .foregroundStyle(Palette.textTertiary)
                                .monospacedDigit()
                        }
                        Text(item.title)
                            .font(MonoFont.body(13, weight: .semibold))
                            .foregroundStyle(Palette.text)
                        Text(item.detail)
                            .font(MonoFont.body(12))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.vertical, Spacing.sm)
                    .overlay(alignment: .bottom) { Palette.separator.frame(height: 0.5) }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 48)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar(showRefresh: false) }
        .accessibilityIdentifier(AccessibilityIDs.tabActivity)
        .confirmationDialog("Clear activity?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear activity", role: .destructive) { session.clearActivity() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Permanently remove \(session.recentActivity.count) locally stored activity \(session.recentActivity.count == 1 ? "entry" : "entries") from this device?"
            )
        }
    }
}
