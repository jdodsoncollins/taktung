import SwiftUI

struct SearchView: View {
    @Environment(AppSession.self) private var session
    @State private var query = ""
    @State private var result: SiteSearchResult?
    @State private var submittedQuery = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Find in your workspace").font(.title2.weight(.semibold))
                    TextField("Search workspace", text: $query, prompt: Text("Site name, ready, failed or environment").foregroundStyle(Palette.textSecondary))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.search).focused($inputFocused)
                        .padding(Spacing.md)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.button))
                        .overlay(RoundedRectangle(cornerRadius: Radii.button).strokeBorder(Palette.border, lineWidth: 0.5))
                        .onSubmit { run() }
                        .onChange(of: query) { _, value in
                            if value != submittedQuery { result = nil }
                        }
                        .accessibilityIdentifier(AccessibilityIDs.commandOpen)
                    PrimaryButton(title: "Search", disabled: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy) { run() }
                        .accessibilityIdentifier("takt.search.submit")
                }
                if !session.connection.isConnected {
                    ContentUnavailableView("Connect to search", systemImage: "magnifyingglass", description: Text("Connect your Vercel account in Settings to find sites and inspect their deployments."))
                    Button("Open Settings") { session.settingsOpen = true }
                } else if let result {
                    results(result)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Quick searches").font(.headline)
                        ForEach(SearchPrompts.examples(site: session.selectedProject.map(siteTitle)), id: \.self) { example in
                            Button { query = example; run() } label: {
                                Label(example, systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }.font(.subheadline)
                        }
                    }
                }
            }.foregroundStyle(Palette.text).frame(maxWidth: .infinity, alignment: .leading).padding(Spacing.lg)
        }
        .taktCanvas().navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar(showRefresh: false) }
        .accessibilityIdentifier(AccessibilityIDs.tabSearch)
    }

    @ViewBuilder private func results(_ result: SiteSearchResult) -> some View {
        switch result {
        case .sites(let projects):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Sites").font(.headline)
                Text("Select a site to open its production overview.").font(.subheadline).foregroundStyle(Palette.textSecondary)
                ForEach(projects) { project in
                    SiteRowView(project: project, selected: false) {
                        Task {
                            await session.selectProject(project.id)
                            guard session.selectedProjectId == project.id else { return }
                            TaktRouter.open(.home)
                        }
                    }.accessibilityIdentifier("takt.search.site.\(project.id)")
                }
            }.accessibilityIdentifier("takt.search.results")
        case .deployments(let title, let items):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title).font(.headline)
                if items.isEmpty {
                    Text("None in this site's loaded deployment history.").foregroundStyle(Palette.textSecondary)
                } else {
                    ForEach(items) { deployment in
                        NavigationLink { DeploymentDetailView(deployment: deployment) } label: {
                            DeploymentRowView(deployment: deployment)
                        }.buttonStyle(.plain)
                    }
                }
            }.accessibilityIdentifier("takt.search.results")
        case .environment:
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Environment").font(.headline)
                if let drift = session.envDrift {
                    Text(drift.summary)
                    ForEach(drift.findings) { finding in Text(finding.detail).font(.subheadline).foregroundStyle(Palette.textSecondary) }
                } else {
                    Text("Check variable names across Preview and Production for the selected site.")
                        .font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                PrimaryButton(title: "Check environment", disabled: session.isBusy) { Task { await session.runEnvDrift() } }
            }
        case .chooseSite:
            ContentUnavailableView("Choose a site", systemImage: "globe", description: Text("Deployment and environment searches use one selected site."))
            Button("Choose a site") { session.sitePickerOpen = true }
        case .noMatch:
            ContentUnavailableView.search(text: query)
        }
    }

    private func run() {
        inputFocused = false
        submittedQuery = query
        result = searchLoadedSite(query, projects: session.projects, deployments: session.deployments,
                                  selectedProjectID: session.selectedProjectId)
    }
}

enum SearchPrompts {
    static func examples(site: String?) -> [String] {
        var examples = ["Ready deployments", "Failed deployments", "Environment"]
        if let site, !site.isEmpty { examples.insert(site, at: 0) }
        return examples
    }
}
