import SwiftUI

struct ProjectToolsView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        List {
            Group {
            Section {
                NavigationLink { WebAnalyticsView() } label: {
                    toolLabel("Analytics", detail: "Visitors, page views and traffic sources", symbol: "chart.xyaxis.line")
                }.accessibilityIdentifier("takt.tools.analytics")
                NavigationLink { RuntimeLogsView() } label: {
                    toolLabel("Runtime logs", detail: "A bounded stream from a selected deployment", symbol: "waveform.path")
                }.accessibilityIdentifier("takt.tools.runtime")
                ForEach(ProjectTool.allCases) { tool in
                    NavigationLink { ProjectInspectionView(tool: tool) } label: {
                        toolLabel(tool.title, detail: tool.detail, symbol: tool.symbol)
                    }.accessibilityIdentifier("takt.tools.\(tool.rawValue)")
                }
            } header: {
                Text(session.selectedProject.map(siteTitle) ?? "Choose a site")
                    .textCase(nil).font(.headline).foregroundStyle(Palette.text)
            } footer: {
                Text("Read-only evidence from your connected Vercel workspace. Availability depends on your role and plan.")
            }
            }.listRowBackground(Palette.background)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .taktCanvas()
        .navigationTitle("Project tools")
        .navigationBarTitleDisplayMode(.large)
    }

    private func toolLabel(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol).foregroundStyle(Palette.accent).frame(width: 24).padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(Palette.text)
                Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }.padding(.vertical, Spacing.sm)
    }
}

struct ProjectInspectionView: View {
    @Environment(AppSession.self) private var session
    let tool: ProjectTool
    var deployment: VercelDeploymentSummary? = nil
    @State private var selection = ""
    @State private var result: InspectionResult?
    @State private var failure: InspectionFailure?
    @State private var loading = false
    @State private var query = ""
    @State private var category = "All"
    @State private var revision = UUID()

    private var deploymentID: String? { deployment?.id ?? evidenceDeploymentID(session: session, selection: selection) }
    private var loadKey: InspectionLoadKey {
        InspectionLoadKey(scope: session.inspectionScope, deploymentID: tool == .checks ? deploymentID : nil, revision: revision)
    }

    var body: some View {
        List {
            Group {
            if tool == .checks, deployment == nil {
                Section { EvidenceDeploymentPicker(selection: $selection) }
            }
            if tool == .checks, let deployment = deployment ?? session.deployments.first(where: { $0.id == deploymentID }) {
                Section { Text(deploymentTitle(deployment)).font(.subheadline).foregroundStyle(Palette.textSecondary) }
            }
            if loading {
                ProgressView("Loading \(tool.title.lowercased())…")
            } else if let failure {
                InspectionFailureView(failure: failure) { revision = UUID() }
            } else if let result {
                if tool == .activity {
                    Picker("Event type", selection: $category) {
                        ForEach(["All", "Deployments", "Domains", "Project"], id: \.self) { Text($0).tag($0) }
                    }
                }
                let rows = filterInspectionRows(result.rows, query: query, category: category)
                if rows.isEmpty {
                    ContentUnavailableView(query.isEmpty && category == "All" ? result.emptyTitle : "No matching records",
                                           systemImage: tool.symbol,
                                           description: Text(query.isEmpty && category == "All" ? "Vercel returned an empty result for this scope." : "Try another search or filter."))
                } else {
                    ForEach(rows) { InspectionRowView(row: $0) }
                }
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(result.note)
                    Text("Fetched \(result.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                }.font(.caption).foregroundStyle(Palette.textSecondary).listRowSeparator(.hidden)
            } else if session.inspectionScope == nil {
                ContentUnavailableView("Choose a connected site", systemImage: "server.rack")
            } else if tool == .checks, deploymentID == nil {
                ContentUnavailableView("No deployment available", systemImage: "checkmark.shield", description: Text("Refresh the site's deployments before inspecting checks."))
            }
            }.listRowBackground(Palette.background)
        }
        .listStyle(.plain).scrollContentBackground(.hidden).taktCanvas()
        .navigationTitle(tool.title).navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search \(tool.title.lowercased())")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { revision = UUID() }.disabled(loading)
            }
        }
        .task(id: loadKey) { await load() }
        .accessibilityIdentifier("takt.inspection.\(tool.rawValue)")
    }

    private func load() async {
        result = nil; failure = nil; loading = false
        guard let scope = session.inspectionScope, tool != .checks || deploymentID != nil else { return }
        let key = loadKey
        loading = true
        defer { if key == loadKey { loading = false } }
        do {
            let value = try await session.inspectProject(tool, scope: scope, deploymentID: tool == .checks ? deploymentID : nil)
            guard !Task.isCancelled, key == loadKey else { return }
            result = value
        } catch {
            guard !Task.isCancelled, key == loadKey, session.inspectionScope == scope else { return }
            failure = InspectionFailure(error)
        }
    }
}

struct InspectionLoadKey: Hashable {
    var scope: InspectionScope?
    var deploymentID: String?
    var revision: UUID
}

struct InspectionFailureView: View {
    let failure: InspectionFailure
    var retry: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label(failure.title, systemImage: "exclamationmark.circle")
        } description: { Text(failure.detail) } actions: { Button("Try again", action: retry).buttonStyle(.bordered) }
    }
}

private struct InspectionRowView: View {
    let row: InspectionRow
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(row.title).font(.body.weight(.medium)).textSelection(.enabled)
            if !row.detail.isEmpty { Text(row.detail).font(.subheadline).foregroundStyle(Palette.textSecondary).textSelection(.enabled) }
            if let state = row.state {
                Label(state, systemImage: symbol).font(.caption.weight(.medium)).foregroundStyle(color)
            }
            if let date = row.date { Text(date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.caption).foregroundStyle(Palette.textSecondary) }
        }.padding(.vertical, Spacing.sm)
    }
    private var color: Color {
        switch row.tone { case .ready: Palette.ready; case .warning: Palette.building; case .error: Palette.danger; case .neutral: Palette.textSecondary }
    }
    private var symbol: String {
        switch row.tone { case .ready: "checkmark.circle"; case .warning: "exclamationmark.circle"; case .error: "xmark.circle"; case .neutral: "minus.circle" }
    }
}

@MainActor
func evidenceDeploymentID(session: AppSession, selection: String) -> String? {
    if !selection.isEmpty { return selection }
    return session.selectedProject?.productionDeployment?.id ?? session.deployments.first?.id
}

struct EvidenceDeploymentPicker: View {
    @Environment(AppSession.self) private var session
    @Binding var selection: String
    var body: some View {
        Picker("Deployment", selection: $selection) {
            Text("Current production or latest").tag("")
            ForEach(session.deployments) { deployment in
                Text("\(deploymentTitle(deployment)) · \(deployment.target?.rawValue ?? "preview")").tag(deployment.id)
            }
        }.accessibilityIdentifier("takt.evidence.deployment")
    }
}
