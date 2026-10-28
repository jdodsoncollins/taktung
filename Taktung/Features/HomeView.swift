import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Group {
            if session.connection.isConnected, let project = session.selectedProject {
                AdaptiveWorkspace {
                    VStack(alignment: .leading, spacing: Spacing.xl) {
                        banners
                        if let visit = session.sinceLastVisit, visit.projectID == project.id {
                            SinceLastVisitCard(visit: visit, generating: session.isGeneratingVisitDigest)
                        }
                        SiteRackView(project: project)
                        reviewTask
                        NavigationLink {
                            ProjectToolsView()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                taskRow("Project tools", symbol: "square.grid.2x2")
                                Text("Runtime logs, activity, domains and deployment checks")
                                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                                    .padding(.horizontal, Spacing.lg).padding(.bottom, Spacing.lg)
                            }
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.plate))
                        }.buttonStyle(.plain).accessibilityIdentifier("takt.home.tools")
                    }
                } secondary: {
                    siteChecks
                }
            } else {
                projectList
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar() }
        .refreshable { await session.refreshProjects() }
        .accessibilityIdentifier(AccessibilityIDs.tabHome)
    }

    private var projectList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                banners
                if session.isRehydrating {
                    ProgressView("Loading your sites…").frame(maxWidth: .infinity, minHeight: 120)
                } else if !session.connection.isConnected {
                    ContentUnavailableView {
                        Label("Connect to Vercel", systemImage: "server.rack")
                    } description: {
                        Text("Inspect deployments, compare changes and keep a record of your checks.")
                    } actions: {
                        Button("Open Settings") { session.settingsOpen = true }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier(AccessibilityIDs.connectButton)
                    }
                } else {
                    Text("Your sites").font(.title2.weight(.semibold))
                    VStack(spacing: 0) {
                        ForEach(rankSites(session.projects)) { project in
                            SiteRowView(project: project, selected: false) {
                                Task { await session.selectProject(project.id) }
                            }
                        }
                    }.accessibilityIdentifier(AccessibilityIDs.projectList)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(Spacing.lg)
        }.taktCanvas()
    }

    @ViewBuilder private var banners: some View {
        if session.pollingDeploymentId != nil {
            Label("Waiting for Vercel to confirm the deployment…", systemImage: "clock")
                .font(.subheadline).foregroundStyle(Palette.textSecondary)
        }
        if let error = session.lastError {
            Label(error, systemImage: "exclamationmark.circle")
                .font(.subheadline).foregroundStyle(Palette.danger)
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private var reviewTask: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Review a change").font(.headline)
            if let candidate = session.deployments.first(where: { $0.state == .ready }) {
                NavigationLink {
                    DeploymentDetailView(deployment: candidate, initialPane: .compare)
                } label: {
                    HStack(spacing: Spacing.md) {
                        if !textSize.isAccessibilitySize {
                            Image(systemName: "rectangle.split.2x1").foregroundStyle(Palette.accent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Compare deployments").font(.body.weight(.medium))
                            Text(deploymentTitle(candidate)).font(.subheadline).foregroundStyle(Palette.textSecondary)
                                .lineLimit(2)
                        }
                        Spacer(minLength: Spacing.sm)
                        if !textSize.isAccessibilitySize {
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.textSecondary)
                        }
                    }.padding(Spacing.lg).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.plate))
                        .overlay(RoundedRectangle(cornerRadius: Radii.plate).strokeBorder(Palette.border, lineWidth: 0.5))
                }.buttonStyle(.plain).accessibilityIdentifier("takt.home.compare")
            } else {
                Text("A successful deployment is needed to capture a page for comparison.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }.foregroundStyle(Palette.text)
    }

    private var siteChecks: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Checks").font(.headline)
                VStack(spacing: 0) {
                    if session.canDiagnose {
                        Button { Task { await session.runOpsBrief() } } label: {
                            taskRow("Check site health", symbol: "stethoscope")
                        }.accessibilityIdentifier(AccessibilityIDs.diagnose)
                            .accessibilityHint("Explains the loaded site signals, with a local heuristic on every device")
                    }
                    Divider()
                    Button { Task { await session.runEnvDrift() } } label: {
                        taskRow("Check environment", symbol: "slider.horizontal.3")
                    }
                    if session.selectedProject?.latestFailedDeployment != nil || session.deployments.contains(where: { isFailedState($0.state) }) {
                        Divider()
                        Button { Task { await session.runIncidentSummary(); await session.runOpsBrief() } } label: {
                            taskRow("Investigate failed build", symbol: "exclamationmark.bubble")
                        }
                    }
                }
                .buttonStyle(.plain).disabled(session.isBusy)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.plate))
                .overlay(RoundedRectangle(cornerRadius: Radii.plate).strokeBorder(Palette.border, lineWidth: 0.5))
            }
            if let narrative = session.opsNarrative {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(narrative.headline).font(.headline)
                    if session.isGeneratingBrief {
                        ProgressView("Summarizing on device…").font(.caption)
                    } else if narrative.source == .appleFoundation {
                        Label("Apple Intelligence", systemImage: "apple.intelligence")
                            .font(.caption).foregroundStyle(Palette.textSecondary)
                    }
                    Text(narrative.body).font(.body).foregroundStyle(Palette.textSecondary)
                    ForEach(Array(narrative.nextSteps.enumerated()), id: \.offset) { _, step in
                        Label(step, systemImage: "arrow.right").font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            if let drift = session.envDrift {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Environment").font(.headline)
                    Text(drift.summary).font(.body)
                    ForEach(Array(drift.findings.enumerated()), id: \.offset) { _, finding in
                        Text(finding.detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            let other = session.projects.filter { $0.needsAttention && $0.id != session.selectedProjectId }.count
            if other > 0 {
                Button { session.sitePickerOpen = true } label: {
                    Label("\(other) other site\(other == 1 ? " needs" : "s need") attention", systemImage: "exclamationmark.circle")
                }.font(.subheadline)
            }
        }.foregroundStyle(Palette.text)
    }

    private func taskRow(_ title: String, symbol: String) -> some View {
        HStack(spacing: Spacing.md) {
            if !textSize.isAccessibilitySize {
                Image(systemName: symbol).frame(width: 24).foregroundStyle(Palette.textSecondary)
            }
            Text(title).font(.body).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.sm)
            if !textSize.isAccessibilitySize {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.textSecondary)
            }
        }.foregroundStyle(Palette.text).padding(.horizontal, Spacing.lg).padding(.vertical, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
    }
}

/// What changed on the site since it was last on screen. Counts come from the
/// loaded deployments; Apple Intelligence may only rephrase them.
private struct SinceLastVisitCard: View {
    var visit: SinceLastVisit
    var generating: Bool

    var body: some View {
        if visit.isQuiet {
            Label(visit.summary, systemImage: "checkmark.circle")
                .font(.subheadline).foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("takt.home.sinceLastVisit")
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Since you last looked").font(.headline)
                Text(visit.summary).font(.body).foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if generating {
                    ProgressView("Summarizing on device…").font(.caption)
                } else if visit.usedAppleIntelligence {
                    Label("Apple Intelligence", systemImage: "apple.intelligence")
                        .font(.caption).foregroundStyle(Palette.textSecondary)
                }
                ForEach(visit.failed.prefix(3)) { deployment in
                    NavigationLink { DeploymentDetailView(deployment: deployment) } label: {
                        DeploymentRowView(deployment: deployment)
                    }.buttonStyle(.plain)
                }
                if visit.failed.count > 3 {
                    Text("\(visit.failed.count - 3) more failed. See Deploys.")
                        .font(.footnote).foregroundStyle(Palette.textSecondary)
                }
            }
            .foregroundStyle(Palette.text)
            .padding(Spacing.lg).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.plate))
            .overlay(RoundedRectangle(cornerRadius: Radii.plate).strokeBorder(Palette.border, lineWidth: 0.5))
            .accessibilityIdentifier("takt.home.sinceLastVisit")
        }
    }
}

struct SiteRowView: View {
    var project: VercelProject
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(siteTitle(project)).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: Spacing.sm)
                    if selected { Image(systemName: "checkmark").foregroundStyle(Palette.accent) }
                }
                if let meta = siteMetaLine(project) {
                    Text(meta).font(.subheadline).foregroundStyle(Palette.textSecondary).lineLimit(2)
                }
                StateWord(label: project.productionDeployment?.state.rawValue ?? "Not deployed",
                          tone: deploymentStateTone(project.productionDeployment?.state ?? .unknown))
            }.frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Palette.text)
                .padding(.vertical, Spacing.lg).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .overlay(alignment: .bottom) { Palette.separator.frame(height: 0.5) }
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
