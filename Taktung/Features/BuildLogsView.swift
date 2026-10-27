import SwiftUI

struct BuildLogsView: View {
    @Environment(AppSession.self) private var session
    let deploymentID: DeploymentID
    var initiallyErrorsOnly = false
    @State private var lines: [BuildLogLine] = []
    @State private var loading = false
    @State private var failure: InspectionFailure?
    @State private var query = ""
    @State private var errorsOnly = false
    @State private var revision = UUID()
    @State private var fetchedAt: Date?

    private var key: InspectionLoadKey { .init(scope: session.inspectionScope, deploymentID: deploymentID, revision: revision) }
    private var visible: [IndexedBuildLogLine] { filterBuildLogs(lines, query: query, errorsOnly: errorsOnly) }
    private var copyText: String { visible.map { $0.line.text }.joined(separator: "\n") }

    var body: some View {
        List {
            Group {
            Section {
                Toggle("Errors only", isOn: $errorsOnly)
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(visible.count) of \(lines.count) loaded lines · latest 500 maximum")
                    Text("Log assignments and recognized credentials are concealed.")
                }.font(.caption).foregroundStyle(Palette.textSecondary)
            }
            if loading { ProgressView("Loading build logs…") }
            else if let failure { InspectionFailureView(failure: failure) { revision = UUID() } }
            else if visible.isEmpty {
                ContentUnavailableView(lines.isEmpty ? "No build logs returned" : "No matching lines", systemImage: "text.alignleft",
                                       description: Text("Error filtering matches stderr and error-like text in the loaded window."))
            } else {
                ForEach(visible) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        if let ms = item.line.created, ms.isFinite {
                            Text(Date(timeIntervalSince1970: ms / 1_000), format: .dateTime.hour().minute().second())
                                .font(.caption.monospacedDigit()).foregroundStyle(Palette.textSecondary)
                        }
                        Text(item.line.text).font(MonoFont.body(13))
                            .foregroundStyle(isErrorLikeBuildLine(item.line) ? Palette.danger : Palette.text)
                            .textSelection(.enabled)
                    }.padding(.vertical, 5)
                }
            }
            if let fetchedAt { Text("Fetched \(fetchedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(Palette.textSecondary) }
            }.listRowBackground(Palette.background)
        }
        .listStyle(.plain).scrollContentBackground(.hidden).taktCanvas()
        .navigationTitle("Build logs").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search loaded build logs")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(item: copyText) { Label("Share filtered logs", systemImage: "square.and.arrow.up") }.disabled(visible.isEmpty)
                Button("Copy filtered logs", systemImage: "doc.on.doc") { UIPasteboard.general.string = copyText }.disabled(visible.isEmpty)
                Button("Refresh", systemImage: "arrow.clockwise") { revision = UUID() }.disabled(loading)
            }
        }
        .task(id: key) { await load() }
        .onAppear { errorsOnly = initiallyErrorsOnly }
        .accessibilityIdentifier("takt.build.logs")
    }

    private func load() async {
        let requestKey = key
        lines = []; fetchedAt = nil; failure = nil; loading = true
        defer { if key == requestKey { loading = false } }
        do {
            let value = try await session.loadBuildLogs(for: deploymentID)
            guard !Task.isCancelled, requestKey == key else { return }
            lines = value; fetchedAt = Date()
        } catch {
            guard !Task.isCancelled, requestKey == key else { return }
            failure = InspectionFailure(error)
        }
    }
}
