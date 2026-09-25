import SwiftUI

struct SearchView: View {
    @Environment(AppSession.self) private var session
    @State private var query = ""
    @State private var result: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                TextField("Ask about the loaded site", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body)
                    .padding(Spacing.md)
                    .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                            .strokeBorder(Palette.border, lineWidth: 0.5)
                    )
                    .onSubmit { run() }
                    .accessibilityIdentifier(AccessibilityIDs.commandOpen)

                PrimaryButton(title: "Look up") { run() }

                if let result {
                    Plate {
                        Text(result)
                            .font(.body)
                            .foregroundStyle(Palette.text)
                            .textSelection(.enabled)
                    }
                } else if session.connection.isConnected {
                    promptChips
                } else {
                    connectInstructions
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
        }
        .taktCanvas()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar(showRefresh: false) }
        .accessibilityIdentifier(AccessibilityIDs.tabSearch)
    }

    private var promptChips: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionLabel(text: "Try")
            FlowChips(titles: SearchPrompts.examples(site: session.selectedProject.map(siteTitle))) { title in
                query = title
                result = session.routeSearch(title)
            }
            Text("On-device when Apple Intelligence is available; otherwise a local lookup over loaded signals. Env values never enter this brief.")
                .font(.footnote)
                .foregroundStyle(Palette.textTertiary)
        }
    }

    private var connectInstructions: some View {
        Plate {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel(text: "Connect first")
                Text("Paste a Vercel personal access token in Settings. Search then looks up the loaded sites, READY, failed deploys, and env names. Values are never shown.")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                PrimaryButton(title: "Open Settings") {
                    session.settingsOpen = true
                }
            }
        }
    }

    private func run() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            result = nil
            return
        }
        result = session.routeSearch(trimmed)
    }
}

enum SearchPrompts {
    static func examples(site: String?) -> [String] {
        var prompts = ["READY", "failed", "env"]
        if let site, !site.isEmpty {
            prompts.insert(site, at: 0)
        }
        return prompts
    }
}

private struct FlowChips: View {
    var titles: [String]
    var onSelect: (String) -> Void

    var body: some View {
        FlexibleChipRow(titles: titles, onSelect: onSelect)
    }
}

private struct FlexibleChipRow: View {
    var titles: [String]
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(titles, id: \.self) { title in
                    FilterChip(label: title, selected: false) { onSelect(title) }
                        .lineLimit(1)
                }
            }
        }
    }
}
