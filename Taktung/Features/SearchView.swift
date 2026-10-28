import SwiftUI

struct SearchView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(SearchPreferences.appleIntelligenceKey) private var useAppleIntelligence = true
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var phase: SearchPhase = .idle
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    /// Idle shows suggestions; every other phase belongs to `submittedQuery`.
    /// Clearing the field, New search, or editing the text returns to idle.
    enum SearchPhase {
        case idle
        case interpreting
        case loading(DeploymentQuery, SearchInterpreter)
        case deployments(DeploymentQuery, [VercelDeploymentSummary], SearchInterpreter)
        case failed(DeploymentQuery, SearchInterpreter, String)
        case sites([VercelProject])
        case otherSite(VercelProject, DeploymentQuery)
        case environment
        case chooseSite
        case noMatch

        var isIdle: Bool {
            guard case .idle = self else { return false }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Find in your workspace").font(.title2.weight(.semibold))
                    field
                    PrimaryButton(title: "Search", disabled: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isBusy) { run() }
                        .accessibilityIdentifier("takt.search.submit")
                }
                if !session.connection.isConnected {
                    ContentUnavailableView("Connect to search", systemImage: "magnifyingglass", description: Text("Connect your Vercel account in Settings to find sites and inspect their deployments."))
                    Button("Open Settings") { session.settingsOpen = true }
                } else {
                    content
                }
            }.foregroundStyle(Palette.text).frame(maxWidth: .infinity, alignment: .leading).padding(Spacing.lg)
        }
        .taktCanvas().navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar(showRefresh: false) }
        .accessibilityIdentifier(AccessibilityIDs.tabSearch)
        .task {
            // A search that asked to switch or choose a site resumes here.
            guard let pending = session.pendingSearch, session.selectedProjectId != nil else { return }
            session.pendingSearch = nil
            run(pending)
        }
    }

    private var field: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Search workspace", text: $query, prompt: Text("Try “successful deploys this week”").foregroundStyle(Palette.textSecondary))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search).focused($inputFocused)
                .onSubmit { run() }
                .onChange(of: query) { _, value in
                    if value != submittedQuery, !phase.isIdle { returnToSuggestions(focus: false) }
                }
                .accessibilityIdentifier(AccessibilityIDs.commandOpen)
            if !query.isEmpty {
                Button { returnToSuggestions(focus: true) } label: {
                    Image(systemName: "xmark.circle.fill").font(.body).foregroundStyle(Palette.textSecondary)
                        .frame(minWidth: 28, minHeight: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("takt.search.clear")
            }
        }
        .padding(Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.button))
        .overlay(RoundedRectangle(cornerRadius: Radii.button).strokeBorder(Palette.border, lineWidth: 0.5))
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .idle:
            suggestions
        case .interpreting:
            ProgressView("Searching…").frame(maxWidth: .infinity)
        case .loading(let q, let interpreter):
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultsHeader(q.title, query: q, interpreter: interpreter)
                ProgressView("Searching…").frame(maxWidth: .infinity)
            }
        case .deployments(let q, let items, let interpreter):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                resultsHeader(q.title, query: q, interpreter: interpreter, count: items.count)
                if items.isEmpty {
                    outcome("No matching deployments", systemImage: "magnifyingglass", detail: emptyDetail(q))
                } else {
                    ForEach(items) { deployment in
                        NavigationLink { DeploymentDetailView(deployment: deployment) } label: {
                            DeploymentRowView(deployment: deployment)
                        }.buttonStyle(.plain)
                    }
                }
            }.accessibilityIdentifier("takt.search.results")
        case .failed(let q, let interpreter, let message):
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultsHeader(q.title, query: q, interpreter: interpreter)
                outcome("Search failed", systemImage: "exclamationmark.triangle", detail: message)
                PrimaryButton(title: "Try again", role: .ghost) { rerun(q, interpreter: interpreter) }
            }
        case .sites(let projects):
            VStack(alignment: .leading, spacing: Spacing.sm) {
                resultsHeader("Sites", query: nil, interpreter: .rules)
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
        case .otherSite(let project, let q):
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultsHeader(q.title, query: nil, interpreter: .rules)
                // The action comes first so it stays on screen at accessibility sizes.
                PrimaryButton(title: "Switch to \(siteTitle(project))") {
                    session.pendingSearch = submittedQuery
                    Task { await session.selectProject(project.id) }
                }
                Text("This search names another site. Switching runs it there.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .environment:
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultsHeader("Environment", query: nil, interpreter: .rules)
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
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultsHeader("Choose a site", query: nil, interpreter: .rules)
                PrimaryButton(title: "Choose a site") {
                    session.pendingSearch = submittedQuery
                    session.sitePickerOpen = true
                }
                Text("Deployment and environment searches use one site. Choose one and this search runs there.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .noMatch:
            VStack(alignment: .leading, spacing: Spacing.md) {
                resultsHeader("No results", query: nil, interpreter: .rules)
                ContentUnavailableView.search(text: submittedQuery)
            }
        }
    }

    private func resultsHeader(_ title: String, query: DeploymentQuery?, interpreter: SearchInterpreter, count: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text(title).font(.headline).fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize { Spacer() }
                Button { returnToSuggestions(focus: true) } label: {
                    Label("New search", systemImage: "arrow.uturn.backward")
                        .font(.subheadline).frame(minHeight: 44)
                }
                .accessibilityIdentifier("takt.search.new")
            }
            if let query {
                let filters = query.filters
                if !filters.isEmpty {
                    ChipFlow {
                        ForEach(filters) { filter in
                            RemovableFilterChip(label: filter.label) { narrow(to: query.removing(filter.kind), interpreter: interpreter) }
                        }
                    }
                }
                if let count, let coverage = query.coverage(count: count, source: session.evidenceScope?.isDemo == true ? "demo data" : "Vercel") {
                    Text(coverage).font(.footnote).foregroundStyle(Palette.textSecondary)
                }
            }
            if interpreter == .appleIntelligence {
                Label("Interpreted with Apple Intelligence on this device", systemImage: "sparkle")
                    .font(.footnote).foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            if session.showsSearchModelControls { intelligenceBadge }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Quick searches").font(.headline)
                ForEach(SearchPrompts.examples(site: session.selectedProject.map(siteTitle)), id: \.self) { example in
                    Button { run(example) } label: {
                        Label(example, systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.font(.subheadline)
                }
            }
            if !session.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Recent").font(.headline)
                        Spacer()
                        Button("Clear") { session.clearRecentSearches() }.font(.subheadline)
                            .accessibilityLabel("Clear recent searches")
                    }
                    ForEach(session.recentSearches, id: \.self) { recent in
                        Button { run(recent) } label: {
                            Label(recent, systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }.font(.subheadline)
                    }
                }
            }
            Text(hint).font(.footnote).foregroundStyle(Palette.textSecondary)
        }
    }

    /// Without Apple Intelligence, or with the switch off, the built-in rules
    /// answer on their own.
    private var intelligenceBadge: some View {
        Toggle(isOn: $useAppleIntelligence) {
            Label {
                Text("Apple Intelligence used for deeper searching")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "sparkle").imageScale(.small).foregroundStyle(Palette.accent)
            }
            .font(.footnote).foregroundStyle(Palette.textSecondary)
        }
        .controlSize(.mini)
        .tint(Palette.accent)
        .padding(.horizontal, Spacing.md).padding(.vertical, Spacing.xs)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radii.button, style: .continuous).strokeBorder(Palette.border, lineWidth: 0.5))
        .accessibilityHint("When on, Apple Intelligence on this device reads phrasing the built-in rules don't recognise")
        .accessibilityIdentifier("takt.search.appleIntelligence")
    }

    private var hint: String {
        let base = "Ask in your own words, like “last successful deploy on main” or “failed preview builds yesterday”. Deployment searches are read-only Vercel requests for the selected site."
        return session.showsSearchModelControls && useAppleIntelligence
            ? base + " Apple Intelligence reads unfamiliar phrasing on this device."
            : base
    }

    private func run(_ text: String? = nil) {
        let text = (text ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputFocused = false
        submittedQuery = text
        query = text
        session.rememberSearch(text)
        searchTask?.cancel()
        phase = .interpreting
        searchTask = Task {
            let interpretation = await session.interpretSearch(text, allowModel: useAppleIntelligence)
            guard !Task.isCancelled, submittedQuery == text else { return }
            switch interpretation.plan {
            case .deployments(let q): await load(q, interpreter: interpretation.interpreter)
            case .sites(let projects): phase = .sites(projects)
            case .otherSite(let project, let q): phase = .otherSite(project, q)
            case .environment: phase = .environment
            case .chooseSite: phase = .chooseSite
            case .noMatch: phase = .noMatch
            }
        }
    }

    private func outcome(_ title: String, systemImage: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label(title, systemImage: systemImage).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.sm)
    }

    private func emptyDetail(_ q: DeploymentQuery) -> String {
        if let text = q.text {
            return "No commit message, branch or author in the newest \(DeploymentQuery.maximumLimit) results contains “\(text)”. If those words weren't meant as commit text, remove that filter."
        }
        return q.hasFilters
            ? "Nothing in this site's deployment history matches these filters. Remove one to widen the search."
            : "This site has no deployments yet."
    }

    /// Removing a chip re-runs the narrower query and rewrites the field to match it.
    private func narrow(to q: DeploymentQuery, interpreter: SearchInterpreter) {
        let phrase = q.phrase
        submittedQuery = phrase
        query = phrase
        rerun(q, interpreter: interpreter)
    }

    private func rerun(_ q: DeploymentQuery, interpreter: SearchInterpreter) {
        searchTask?.cancel()
        searchTask = Task { await load(q, interpreter: interpreter) }
    }

    private func load(_ q: DeploymentQuery, interpreter: SearchInterpreter) async {
        phase = .loading(q, interpreter)
        do {
            let items = try await session.searchDeployments(q)
            guard !Task.isCancelled else { return }
            phase = .deployments(q, items, interpreter)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            phase = .failed(q, interpreter, error.localizedDescription)
        }
    }

    private func returnToSuggestions(focus: Bool) {
        searchTask?.cancel()
        searchTask = nil
        phase = .idle
        if focus {
            submittedQuery = ""
            query = ""
            inputFocused = true
        }
    }
}

/// Wraps filter chips onto as many lines as they need instead of scrolling them off screen.
private struct ChipFlow: Layout {
    var spacing: CGFloat = Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width { x = 0; y += line + spacing; line = 0 }
            x += size.width + spacing
            line = max(line, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += line + spacing; line = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

private struct RemovableFilterChip: View {
    var label: String
    var remove: () -> Void

    var body: some View {
        Button(action: remove) {
            HStack(spacing: Spacing.xs) {
                Text(label).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "xmark").font(.caption2.weight(.semibold)).foregroundStyle(Palette.textSecondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radii.button, style: .continuous).strokeBorder(Palette.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) filter")
        .accessibilityHint("Removes this filter and searches again")
    }
}

enum SearchPreferences {
    /// On by default; only consulted where Apple Intelligence can run.
    static let appleIntelligenceKey = "takt.search.appleIntelligence"
}

enum SearchPrompts {
    static func examples(site: String?) -> [String] {
        var examples = ["Successful deployments", "Failed deployments this week", "Latest production deployment", "Environment"]
        if let site, !site.isEmpty { examples.insert(site, at: 0) }
        return examples
    }
}
