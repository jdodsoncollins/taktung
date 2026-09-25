import SwiftUI

struct DeploymentDetailView: View {
    @Environment(AppSession.self) private var session
    var deployment: VercelDeploymentSummary
    @State private var pane: Pane = .diagnose
    @State private var logs: [BuildLogLine] = []

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
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Plate {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        StateWord(
                            label: deployment.state.rawValue,
                            tone: deploymentStateTone(deployment.state)
                        )
                        Text(deploymentTitle(deployment))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.text)
                        Text(deploymentRefLine(deployment))
                            .font(MonoFont.body(13))
                            .foregroundStyle(Palette.textSecondary)
                        if let provenance = deploymentProvenanceLine(deployment) {
                            Text(provenance)
                                .font(MonoFont.body(12))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
                HStack(spacing: Spacing.sm) {
                    ForEach(Pane.allCases) { item in
                        FilterChip(label: item.label, selected: pane == item) { pane = item }
                            .accessibilityIdentifier(id(for: item))
                    }
                }
                paneBody
                VStack(spacing: Spacing.sm) {
                    PrimaryButton(title: "Redeploy") {
                        Task {
                            await session.selectDeployment(deployment.id)
                            session.requestMutation(mode: .redeploy)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIDs.redeployButton)
                    PrimaryButton(title: "Promote to production", role: .ghost) {
                        Task {
                            await session.selectDeployment(deployment.id)
                            session.requestMutation(mode: .promote)
                        }
                    }
                    PrimaryButton(title: "Rollback production", role: .danger) {
                        Task {
                            await session.selectDeployment(deployment.id)
                            session.requestMutation(mode: .rollback)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
        }
        .taktCanvas()
        .navigationTitle("Deployment")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await session.selectDeployment(deployment.id)
            logs = await session.loadBuildLogs(for: deployment.id)
        }
    }

    @ViewBuilder
    private var paneBody: some View {
        switch pane {
        case .diagnose:
            if let incident = session.incident {
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
            } else {
                PrimaryButton(title: "Run incident summary", role: .ghost) {
                    Task { await session.runIncidentSummary() }
                }
            }
        case .compare:
            Plate {
                Text("Compare uses the last successful production deploy as baseline. No extra list N+1.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
            }
        case .logs:
            Plate {
                VStack(alignment: .leading, spacing: 6) {
                    if logs.isEmpty {
                        Text("No build log lines loaded.")
                            .font(MonoFont.body(12))
                            .foregroundStyle(Palette.textSecondary)
                    } else {
                        ForEach(Array(logs.suffix(40).enumerated()), id: \.offset) { _, line in
                            Text(line.text)
                                .font(MonoFont.body(12))
                                .foregroundStyle(Palette.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        case .errors:
            Plate {
                let failed = logs.filter {
                    $0.text.localizedCaseInsensitiveContains("error")
                        || $0.type == "stderr"
                }
                if failed.isEmpty {
                    Text("No error-like lines in the loaded tail.")
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    ForEach(Array(failed.prefix(20).enumerated()), id: \.offset) { _, line in
                        Text(line.text)
                            .font(MonoFont.body(12))
                            .foregroundStyle(Palette.danger)
                            .textSelection(.enabled)
                    }
                }
            }
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
