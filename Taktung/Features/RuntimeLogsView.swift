import SwiftUI

struct RuntimeLogsView: View {
    @Environment(AppSession.self) private var session
    var deployment: VercelDeploymentSummary? = nil
    @State private var selection = ""
    @State private var entries: [RuntimeLogEntry] = []
    @State private var failure: InspectionFailure?
    @State private var isReading = false
    @State private var listening = true
    @State private var query = ""
    @State private var errorsOnly = false
    @State private var revision = UUID()
    @State private var startedAt: Date?
    @State private var loadedScope: InspectionScope?
    @State private var loadedDeploymentID: String?

    private var deploymentID: String? { deployment?.id ?? evidenceDeploymentID(session: session, selection: selection) }
    private var key: InspectionLoadKey {
        InspectionLoadKey(scope: session.inspectionScope, deploymentID: deploymentID, revision: revision)
    }
    private var visible: [RuntimeLogEntry] {
        entries.filter { (!errorsOnly || $0.isError) && (query.isEmpty || [$0.message, $0.path, $0.level].contains { $0.localizedCaseInsensitiveContains(query) }) }
    }

    var body: some View {
        List {
            Group {
            if deployment == nil { Section { EvidenceDeploymentPicker(selection: $selection) } }
            Section {
                if let selected = deployment ?? session.deployments.first(where: { $0.id == deploymentID }) ?? session.selectedProject?.productionDeployment {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(deploymentTitle(selected)).font(.subheadline.weight(.medium))
                        Text(deploymentListMetaLine(selected)).font(.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
                Toggle("Errors only", isOn: $errorsOnly)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label(isReading ? "Receiving runtime logs" : "Stream stopped", systemImage: isReading ? "waveform.path" : "pause.circle")
                        .font(.subheadline)
                    Text("One deployment · up to 500 records or 2 MB per connection. This sample does not establish site uptime or an hourly error total.").font(.caption)
                    if let startedAt { Text("Started \(startedAt.formatted(date: .omitted, time: .standard))").font(.caption) }
                }.foregroundStyle(Palette.textSecondary)
            }
            if let failure { InspectionFailureView(failure: failure, retry: restart) }
            if deploymentID == nil {
                ContentUnavailableView("No deployment available", systemImage: "waveform.path")
            } else if visible.isEmpty, failure == nil {
                ContentUnavailableView(entries.isEmpty ? "No runtime records received" : "No matching records", systemImage: "waveform.path",
                                       description: Text(isReading ? "Requests to this deployment may produce new log records. Keep this screen open to receive them." : "Start another connection to receive deployment logs."))
            } else {
                ForEach(visible) { entry in RuntimeLogRow(entry: entry) }
            }
            }.listRowBackground(Palette.background)
        }
        .listStyle(.plain).scrollContentBackground(.hidden).taktCanvas()
        .navigationTitle("Runtime logs").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search loaded records")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isReading {
                    Button("Stop", systemImage: "stop.circle") { listening = false; revision = UUID() }.accessibilityIdentifier("takt.runtime.stop")
                } else {
                    Button("Start", systemImage: "arrow.clockwise", action: restart).disabled(deploymentID == nil)
                }
            }
        }
        .task(id: key) { await receive() }
        .accessibilityIdentifier("takt.runtime.logs")
    }

    private func restart() { listening = true; revision = UUID() }

    private func receive() async {
        let requestKey = key
        failure = nil; isReading = false
        if loadedScope != session.inspectionScope || loadedDeploymentID != deploymentID {
            entries = []; startedAt = nil
        }
        loadedScope = session.inspectionScope; loadedDeploymentID = deploymentID
        guard listening, let scope = session.inspectionScope, let deploymentID else { return }
        entries = []; startedAt = Date(); isReading = true
        defer { if key == requestKey { isReading = false } }
        do {
            let stream = try await session.runtimeLogStream(scope: scope, deploymentID: deploymentID)
            for try await entry in stream {
                try Task.checkCancellation()
                guard key == requestKey, session.inspectionScope == scope else { return }
                if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry }
                else { entries.append(entry) }
                if entries.count > 500 { entries.removeFirst(entries.count - 500) }
                session.recordRuntimeSample(scope: scope, deploymentID: deploymentID, records: entries.count,
                                            errors: entries.filter(\.isError).count)
            }
        } catch {
            guard !Task.isCancelled, key == requestKey, session.inspectionScope == scope else { return }
            failure = InspectionFailure(error)
        }
    }
}

private struct RuntimeLogRow: View {
    let entry: RuntimeLogEntry
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label(entry.level.capitalized, systemImage: entry.isError ? "exclamationmark.circle" : "text.alignleft")
                    .foregroundStyle(entry.isError ? Palette.danger : Palette.textSecondary)
                if let status = entry.statusCode { Text(String(status)).monospacedDigit() }
                if let date = entry.timestamp { Text(date, format: .dateTime.hour().minute().second()).foregroundStyle(Palette.textSecondary) }
            }.font(.caption)
            if !entry.path.isEmpty { Text(entry.path).font(MonoFont.body(12)).foregroundStyle(Palette.textSecondary) }
            Text(entry.message).font(MonoFont.body(13)).textSelection(.enabled)
        }.padding(.vertical, Spacing.sm)
    }
}
