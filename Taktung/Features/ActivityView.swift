import SwiftUI

struct ActivityView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scope: FieldLogScope = .site
    @State private var filter: FieldLogFilter = .all
    @State private var query = ""
    @State private var confirmClear = false
    @State private var clearScope: EvidenceScope?
    @State private var sheet: FieldLogSheet?
    @State private var visibleIDs = Set<String>()
    @State private var initialized = false
    @State private var atTop = true

    private var matching: [ActivityItem] {
        fieldLogEntries(session.recentActivity, projectID: session.selectedProjectId,
                        scope: scope, filter: filter, search: query)
    }
    private var items: [ActivityItem] { matching.filter { visibleIDs.contains($0.id) } }
    private var pendingCount: Int { matching.filter { !visibleIDs.contains($0.id) }.count }
    private var hasFilters: Bool { filter != .all || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                controls.id("field-log-top")
                    .listRowSeparator(.hidden)
                    .listRowBackground(Palette.background)
                if let error = session.historyStorageError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote).foregroundStyle(Palette.danger)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Palette.background)
                }
                if items.isEmpty {
                    emptyState.listRowSeparator(.hidden).listRowBackground(Palette.background)
                }
                ForEach(fieldLogDays(items)) { day in
                    Section {
                        ForEach(day.entries) { item in
                            NavigationLink {
                                HistoryEntryView(item: item)
                            } label: {
                                HistoryRow(item: item, showSite: scope == .all || session.selectedProjectId == nil)
                            }
                            .id(item.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Palette.background)
                        }
                    } header: {
                        Text(dayTitle(day.date))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.textSecondary)
                            .textCase(nil)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 44)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top <= 8
            } action: { _, value in
                atTop = value
                if value { revealNewEntries() }
            }
            .onAppear {
                if !initialized { revealNewEntries(); initialized = true }
            }
            .onChange(of: session.recentActivity.map(\.id)) { _, _ in
                if atTop { revealNewEntries() }
            }
            .onChange(of: query) { _, _ in showLatest(proxy) }
            .onChange(of: scope) { _, _ in showLatest(proxy) }
            .onChange(of: filter) { _, _ in showLatest(proxy) }
            .onChange(of: session.selectedProjectId) { _, _ in showLatest(proxy) }
            .overlay(alignment: .top) {
                if pendingCount > 0, !atTop {
                    Button("\(pendingCount) new \(pendingCount == 1 ? "entry" : "entries")", systemImage: "arrow.up") {
                        if reduceMotion { showLatest(proxy) }
                        else { withAnimation(.easeInOut(duration: 0.2)) { showLatest(proxy) } }
                    }
                    .buttonStyle(.borderedProminent).padding(.top, Spacing.sm)
                    .accessibilityIdentifier("takt.history.new")
                }
            }
        }
        .taktCanvas().navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ChromeToolbar(showRefresh: false)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add note", systemImage: "square.and.pencil") {
                    guard let scope = session.evidenceScope else { return }
                    sheet = .note(NoteContext(scope: scope, projectID: session.selectedProjectId,
                                             deploymentID: session.selectedDeployment?.id,
                                             projectName: session.selectedProject.map(siteTitle)))
                }
                .disabled(session.evidenceScope == nil || session.historyIsBusy)
                .accessibilityIdentifier("takt.history.note")
            }
        }
        .searchable(text: $query, prompt: "Search field log")
        .accessibilityIdentifier(AccessibilityIDs.tabActivity)
        .confirmationDialog("Clear this account's activity for the current team?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear activity", role: .destructive) {
                guard let clearScope else { return }
                Task { await session.clearActivity(expectedScope: clearScope) }
            }
        } message: {
            Text("Remove all \(session.recentActivity.count) records for this team from this device, including notes. Saved visual baselines are kept.")
        }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .note(let context): HistoryNoteSheet(context: context)
            case .information: FieldLogInformationSheet()
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Field log").font(.title2.weight(.semibold)).foregroundStyle(Palette.text)
                    Text("On this device").font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: Spacing.sm)
                Menu {
                    ShareLink(item: historyExport(items)) { Label("Export visible entries", systemImage: "square.and.arrow.up") }
                        .disabled(items.isEmpty)
                    Button("About this log", systemImage: "info.circle") { sheet = .information }
                    Divider()
                    Button("Clear activity", systemImage: "trash", role: .destructive) {
                        clearScope = session.evidenceScope
                        confirmClear = true
                    }.disabled(session.recentActivity.isEmpty || session.historyIsBusy)
                } label: {
                    Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Field log options")
                .accessibilityIdentifier("takt.history.options")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.md) { scopePicker; filterPicker; Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: 0) { scopePicker; filterPicker }
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var scopePicker: some View {
        Picker("Site scope", selection: $scope) {
            Text("This site").tag(FieldLogScope.site)
            Text("All sites").tag(FieldLogScope.all)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(minHeight: 44)
        .accessibilityIdentifier("takt.history.scope")
    }

    private var filterPicker: some View {
        Menu {
            Picker("Events", selection: $filter) {
                ForEach(FieldLogFilter.allCases, id: \.self) { value in Text(value.title).tag(value) }
            }
        } label: {
            Label(filter.title, systemImage: "line.3.horizontal.decrease")
                .font(.subheadline).frame(minHeight: 44)
        }
        .accessibilityLabel("Event filter, \(filter.title)")
        .accessibilityIdentifier("takt.history.filter")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(hasFilters ? "No matching entries" : "No activity yet", systemImage: hasFilters ? "line.3.horizontal.decrease" : "clock")
        } description: {
            Text(hasFilters ? "Try another search or reset your filters." : "Checks, comparisons, actions, and notes will appear here.")
        } actions: {
            if hasFilters {
                Button("Reset filters") { query = ""; filter = .all }
                    .accessibilityIdentifier("takt.history.reset")
            }
        }
    }

    private func revealNewEntries() { visibleIDs = Set(session.recentActivity.map(\.id)) }
    private func showLatest(_ proxy: ScrollViewProxy) {
        revealNewEntries()
        proxy.scrollTo("field-log-top", anchor: .top)
    }
    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private enum FieldLogSheet: Identifiable {
    case note(NoteContext), information
    var id: String {
        switch self {
        case .note(let context): context.id.uuidString
        case .information: "information"
        }
    }
}

private struct HistoryRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var item: ActivityItem
    var showSite: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol).font(.body).foregroundStyle(markerColor)
                .frame(width: 24, height: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if typeSize.isAccessibilitySize {
                    title
                    timestamp
                } else {
                    HStack(alignment: .firstTextBaseline) { title; Spacer(minLength: Spacing.sm); timestamp }
                }
                if item.outcome == .failure || item.outcome == .canceled {
                    Text(item.outcome == .failure ? "Failed" : "Canceled")
                        .font(.caption.weight(.semibold)).foregroundStyle(markerColor)
                }
                if item.projectId == nil {
                    Text("Account").font(.caption).foregroundStyle(Palette.textSecondary)
                } else if showSite {
                    Text(item.projectName ?? item.projectId ?? "Site").font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Text(item.displayDetail).font(item.kind == .note ? .body : .subheadline)
                    .foregroundStyle(item.kind == .note ? Palette.text : Palette.textSecondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(alignment: .leading) {
            Rectangle().fill(Palette.separator).frame(width: 1)
                .padding(.top, 36).padding(.bottom, 2).offset(x: 11.5).accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayTitle). \(item.outcome.rawValue). \(item.projectName ?? (item.projectId == nil ? "Account" : "Site")). \(item.displayDetail). \(item.createdAt.formatted(date: .complete, time: .shortened))")
    }
    private var title: some View { Text(item.displayTitle).font(.headline).foregroundStyle(Palette.text).fixedSize(horizontal: false, vertical: true) }
    private var timestamp: some View {
        Text(item.createdAt, format: .dateTime.hour().minute()).font(.caption.monospacedDigit())
            .foregroundStyle(Palette.textSecondary).fixedSize()
    }
    private var markerColor: Color {
        item.outcome == .failure ? Palette.danger : Palette.textSecondary
    }
    private var symbol: String {
        if item.outcome == .failure { return "exclamationmark.triangle" }
        if item.outcome == .canceled { return "xmark.circle" }
        switch item.kind {
        case .note: return "note.text"
        case .deploymentCompare: return "rectangle.split.2x1"
        case .redeploy, .promote, .planExecute: return "arrow.up.circle"
        case .rollback: return "arrow.uturn.backward"
        case .deploymentPoll: return item.outcome == .success ? "checkmark.circle" : "clock"
        case .incidentSummary: return "stethoscope"
        case .envDrift: return "slider.horizontal.3"
        case .connect, .disconnect: return "link"
        default: return "doc.text.magnifyingglass"
        }
    }
}

private struct FieldLogInformationSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Local journal") {
                    Text("Actions and observations recorded on this device. This is not a complete Vercel account audit log.")
                    Text("The latest \(LocalEvidenceStore.historyLimit.formatted()) records are kept for each account and team. Notes, checks, and comparison evidence survive app restarts.")
                }
                Section("Privacy and clearing") {
                    Text("Recognizable credentials are redacted before saving and exporting. Environment values are never included.")
                    Text("Clear activity removes the current team's records, including notes. Saved visual baselines are kept. Disconnect in Settings erases the account's local evidence across its teams.")
                }
            }.scrollContentBackground(.hidden).taktCanvas().navigationTitle("About this log")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct HistoryEntryView: View {
    var item: ActivityItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(item.displayTitle).font(.title2.weight(.semibold)).foregroundStyle(Palette.text)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(item.createdAt.formatted(date: .complete, time: .shortened)).font(.subheadline)
                    Label(item.outcome.rawValue.capitalized, systemImage: item.outcome == .failure ? "exclamationmark.triangle" : "clock")
                        .font(.subheadline).foregroundStyle(outcomeTone(item.outcome).color)
                    if let name = item.projectName { Text(name).font(.subheadline) }
                }.foregroundStyle(Palette.textSecondary)
                Divider()
                Text(item.displayDetail).font(.body).foregroundStyle(Palette.text).textSelection(.enabled)
                if let id = item.deploymentId {
                    Text("Deployment: \(id)").font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                        .foregroundStyle(Palette.textSecondary)
                }
                ShareLink(item: historyExport([item])) { Label("Export entry", systemImage: "square.and.arrow.up") }
            }.frame(maxWidth: 760, alignment: .leading).padding(Spacing.lg)
        }.taktCanvas().navigationTitle("Activity entry").navigationBarTitleDisplayMode(.inline)
    }
}

private struct NoteContext: Identifiable {
    let id = UUID()
    var scope: EvidenceScope
    var projectID: ProjectID?
    var deploymentID: DeploymentID?
    var projectName: String?
}

private struct HistoryNoteSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    var context: NoteContext
    @State private var text = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(context.projectName ?? "Account note") {
                    TextField("What happened? What should you check next?", text: $text, axis: .vertical)
                        .lineLimit(8...20).accessibilityIdentifier("takt.history.note.text")
                    Text("Recognizable credentials are redacted before saving.").font(.caption)
                }
                if let error { Text(error).foregroundStyle(Palette.danger) }
            }
            .scrollContentBackground(.hidden).taktCanvas().navigationTitle("Add note")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .topBarPinnedTrailing) {
                    Button("Save") {
                        saving = true
                        Task {
                            if await session.addHistoryNote(text, scope: context.scope, projectID: context.projectID, deploymentID: context.deploymentID, noteID: context.id.uuidString) {
                                dismiss()
                            } else {
                                error = session.historyStorageError ?? "The selected account or site changed. Open a new note."
                                saving = false
                            }
                        }
                    }
                    .disabled(saving || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("takt.history.note.save")
                }
            }
        }
    }
}
