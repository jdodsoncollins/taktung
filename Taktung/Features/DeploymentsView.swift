import SwiftUI

struct DeploymentsView: View {
    @Environment(AppSession.self) private var session
    @State private var filter: DeploymentListFilter = .all

    var body: some View {
        let counts = countDeploymentsByFilter(session.deployments)
        let rows = filterDeployments(session.deployments, filter: filter)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if session.selectedProject == nil {
                    Text("Choose a site to inspect deploys.")
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    SectionLabel(text: "Recent deployments")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach(DeploymentListFilter.allCases) { item in
                                FilterChip(
                                    label: "\(item.label) \(counts[item] ?? 0)",
                                    selected: filter == item
                                ) { filter = item }
                            }
                        }
                    }
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(rows) { deploy in
                            NavigationLink {
                                DeploymentDetailView(deployment: deploy)
                            } label: {
                                DeploymentRowView(deployment: deploy)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIDs.deploymentList)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
            .padding(.bottom, 48)
        }
        .taktCanvas()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar() }
        .refreshable {
            if let id = session.selectedProjectId {
                await session.loadDeployments(id)
            }
        }
        .accessibilityIdentifier(AccessibilityIDs.tabDeployments)
    }
}

struct DeploymentRowView: View {
    var deployment: VercelDeploymentSummary

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            StateWord(label: deployment.state.rawValue, tone: deploymentStateTone(deployment.state))
                .frame(width: 72, alignment: .leading)
            DeploymentPreviewThumb(url: deployment.url, state: deployment.state, variant: .chip)
            VStack(alignment: .leading, spacing: 4) {
                Text(deploymentTitle(deployment))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text(deploymentListMetaLine(deployment))
                    .font(MonoFont.body(12))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.vertical, Spacing.md)
        .overlay(alignment: .bottom) { Palette.separator.frame(height: 0.5) }
        .contentShape(Rectangle())
    }
}
