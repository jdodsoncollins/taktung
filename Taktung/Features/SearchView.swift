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
                }

                if session.canDiagnose {
                    Text("On-device when Apple Intelligence is available; otherwise a local heuristic over loaded signals. Env values never enter this brief.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .padding(Spacing.lg)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ChromeToolbar(showRefresh: false) }
        .accessibilityIdentifier(AccessibilityIDs.tabSearch)
    }

    private func run() {
        result = session.routeSearch(query)
    }
}
