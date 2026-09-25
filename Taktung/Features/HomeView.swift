import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                banners
                bodyContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 48)
        }
        .taktCanvas()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar() }
        .refreshable { await session.refreshProjects() }
        .accessibilityIdentifier(AccessibilityIDs.tabHome)
    }

    @ViewBuilder
    private var banners: some View {
        if session.pollingDeploymentId != nil {
            Plate {
                Text("Deploy poll active. READY only when Vercel confirms.")
                    .font(MonoFont.body(12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        if let error = session.lastError {
            Plate {
                Text(error)
                    .font(MonoFont.body(12))
                    .foregroundStyle(Palette.danger)
            }
            .accessibilityAddTraits(.isStaticText)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        if !session.connection.isConnected && !session.isRehydrating {
            connectPrompt
        } else if let project = session.selectedProject {
            let other = session.projects.filter { $0.needsAttention && $0.id != project.id }.count
            if other > 0 {
                FilterChip(label: "\(other) other site\(other == 1 ? "" : "s")", selected: false) {
                    session.sitePickerOpen = true
                }
            }
            SiteRackView(project: project)
            if session.canDiagnose {
                Button {
                    Task { await session.runOpsBrief() }
                } label: {
                    Text("DIAGNOSE")
                        .font(MonoFont.body(14, weight: .semibold))
                        .tracking(1.4)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .foregroundStyle(Palette.textOnAccent)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radii.stamp, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(AccessibilityIDs.diagnose)
                .accessibilityLabel("Diagnose")
                .accessibilityHint("Runs a local on-device check from loaded site signals")
            }
            if let narrative = session.opsNarrative {
                Plate {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionLabel(text: "Brief")
                        Text(narrative.headline)
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        Text(narrative.body)
                            .font(.body)
                            .foregroundStyle(Palette.textSecondary)
                        ForEach(Array(narrative.nextSteps.enumerated()), id: \.offset) { i, step in
                            Text("\(i + 1). \(step)")
                                .font(.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
            }
        } else if session.connection.isConnected {
            Text("Pick a site to inspect health and deploys.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rankSites(session.projects)) { project in
                    SiteRowView(project: project, selected: false) {
                        Task { await session.selectProject(project.id) }
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityIDs.projectList)
        } else if session.isRehydrating {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private var connectPrompt: some View {
        Plate {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel(text: "Account")
                Text("Connect a Vercel personal access token in Settings, or turn on screenshot demo.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                PrimaryButton(title: "Open Settings") {
                    session.settingsOpen = true
                }
            }
        }
        .accessibilityIdentifier(AccessibilityIDs.connectButton)
    }
}

struct SiteRowView: View {
    var project: VercelProject
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(siteTitle(project))
                        .font(MonoFont.body(14, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    if let meta = siteMetaLine(project) {
                        Text(meta)
                            .font(MonoFont.body(12))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                StateWord(
                    label: project.productionDeployment?.state.rawValue ?? "NONE",
                    tone: deploymentStateTone(project.productionDeployment?.state ?? .unknown)
                )
            }
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Palette.separator.frame(height: 0.5)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
