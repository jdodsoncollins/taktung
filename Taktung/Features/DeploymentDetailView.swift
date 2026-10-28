import SwiftUI

struct DeploymentDetailView: View {
    @Environment(AppSession.self) private var session
    var deployment: VercelDeploymentSummary
    private var current: VercelDeploymentSummary { session.deploymentForDisplay(deployment) }
    @State private var pane: Pane = .diagnose
    @State private var visualComparison = VisualComparisonState()

    init(deployment: VercelDeploymentSummary, initialPane: Pane = .diagnose) {
        self.deployment = deployment
        _pane = State(initialValue: initialPane)
    }

    enum Pane: String, CaseIterable, Identifiable {
        case diagnose
        case compare
        case logs
        case errors
        var id: String { rawValue }
        var label: String {
            switch self {
            case .diagnose: "Diagnose"
            case .compare: "Compare"
            case .logs: "Logs"
            case .errors: "Errors"
            }
        }
    }

    var body: some View {
        AdaptiveWorkspace {
            overview
        } secondary: {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(Pane.allCases) { item in
                            FilterChip(label: item.label, selected: pane == item) { pane = item }
                                .accessibilityIdentifier(id(for: item))
                        }
                    }
                }
                paneBody
                NavigationLink {
                    RuntimeLogsView(deployment: current)
                } label: { Label("Runtime logs", systemImage: "waveform.path") }
                NavigationLink {
                    ProjectInspectionView(tool: .checks, deployment: current)
                } label: { Label("Deployment checks", systemImage: "checkmark.shield") }
                Menu {
                    Button("Redeploy", systemImage: "arrow.clockwise") { requestMutation(.redeploy) }
                    .accessibilityIdentifier(AccessibilityIDs.redeployButton)
                    Button("Promote to production", systemImage: "arrow.up.circle") { requestMutation(.promote) }
                    Button("Rollback production", systemImage: "arrow.uturn.backward", role: .destructive) { requestMutation(.rollback) }
                } label: {
                    Label("Deployment actions", systemImage: "ellipsis.circle")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                }.accessibilityIdentifier("takt.detail.actions")
                .disabled(session.isBusy || !session.knownDeployments.contains { $0.id == deployment.id })
            }
        }
        .navigationTitle("Deployment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await session.selectDeployment(deployment.id)
        }
    }

    private var overview: some View {
        Plate {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                StateWord(
                    label: current.state.rawValue,
                    tone: deploymentStateTone(current.state)
                )
                Text(deploymentTitle(current))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.text)
                Text(deploymentRefLine(current))
                    .font(MonoFont.body(13))
                    .foregroundStyle(Palette.textSecondary)
                if let provenance = deploymentProvenanceLine(current) {
                    Text(provenance)
                        .font(MonoFont.body(12))
                        .foregroundStyle(Palette.textTertiary)
                }
                if pane != .compare, current.state == .ready {
                    DeploymentPreviewThumb(url: current.url, state: current.state, variant: .summary)
                        .frame(maxWidth: .infinity).padding(.top, Spacing.sm)
                }
                if !DemoMode.isEnabled, let page = absoluteDeploymentURL(current.url), let destination = URL(string: page) {
                    Link("Open deployment", destination: destination)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.accent)
                }
            }
        }
    }


    @ViewBuilder
    private var paneBody: some View {
        switch pane {
        case .diagnose:
            if session.incidentDeploymentId == deployment.id, let incident = session.incident {
                Plate {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(incident.headline)
                            .font(.headline)
                            .foregroundStyle(Palette.text)
                        Text(incident.likelyCause ?? "Unknown (low signal)")
                            .font(.body)
                            .foregroundStyle(Palette.textSecondary)
                        Text(incident.suggestedAction)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                if let evidence = session.buildFailure, evidence.deploymentID == deployment.id {
                    BuildFailureEvidenceView(evidence: evidence)
                }
            } else if isFailedState(current.state) {
                PrimaryButton(title: "Run incident summary", role: .ghost) {
                    Task { await session.runIncidentSummary() }
                }
            } else {
                Plate {
                    Text("This deployment is \(current.state.rawValue). Select a failed deployment to diagnose its build.")
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        case .compare:
            VisualComparisonView(deployment: current, comparison: visualComparison)
        case .logs, .errors:
            logPane
        }
    }

    private var logPane: some View {
        Plate {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Search the latest build output, filter error-like lines and copy redacted evidence.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                NavigationLink {
                    BuildLogsView(deploymentID: deployment.id, initiallyErrorsOnly: pane == .errors)
                } label: {
                    Label(pane == .errors ? "Inspect error-like lines" : "Open build logs", systemImage: "text.alignleft")
                        .font(.body.weight(.medium)).frame(minHeight: 44)
                }.accessibilityIdentifier("takt.detail.openLogs")
            }
        }
    }

    private func requestMutation(_ mode: MutationMode) {
        Task {
            await session.selectDeployment(deployment.id)
            session.requestMutation(mode: mode, expectedDeploymentID: deployment.id)
        }
    }

    private func id(for pane: Pane) -> String {
        switch pane {
        case .diagnose: AccessibilityIDs.detailPaneDiagnose
        case .compare: AccessibilityIDs.detailPaneCompare
        case .logs: AccessibilityIDs.detailPaneLogs
        case .errors: AccessibilityIDs.detailPaneErrors
        }
    }

}
