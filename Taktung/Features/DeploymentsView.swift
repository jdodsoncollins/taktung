import SwiftUI

struct DeploymentsView: View {
    @Environment(AppSession.self) private var session
    @State private var filter: DeploymentListFilter = .all
    @State private var target: DeploymentTargetFilter = .all
    @State private var query = ""

    var body: some View {
        let counts = countDeploymentsByFilter(session.deployments)
        let rows = searchDeployments(session.deployments, filter: filter, target: target, query: query)
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if session.selectedProject == nil {
                    Text("Choose a site to inspect deploys.")
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("Deployments").font(.largeTitle.bold())
                    Picker("Environment", selection: $target) {
                        ForEach(DeploymentTargetFilter.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.sm) {
                            ForEach([DeploymentListFilter.all, .failed, .building]) { item in
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
                    if rows.isEmpty {
                        ContentUnavailableView("No matching deployments", systemImage: "arrow.up.right.square", description: Text("Try another search or filter, or refresh this site's deployments."))
                    }
                    Text("Filters apply to the \(session.deployments.count) loaded deployments.")
                        .font(.caption).foregroundStyle(Palette.textSecondary)
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
        .searchable(text: $query, prompt: "Commit, branch, SHA or deployment URL")
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
            DeploymentPreviewThumb(url: deployment.url, state: deployment.state, variant: .chip)
            VStack(alignment: .leading, spacing: 4) {
                Text(deploymentTitle(deployment))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                Text(deploymentListMetaLine(deployment))
                    .font(MonoFont.body(12))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                StateWord(label: deployment.state.rawValue, tone: deploymentStateTone(deployment.state))
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
