import SwiftUI

/// The redacted log lines behind a failed-build diagnosis, with an optional
/// on-device explanation that is always shown next to the lines it came from.
struct BuildFailureEvidenceView: View {
    var evidence: BuildFailureEvidence
    @State private var showsLines = true

    var body: some View {
        Plate {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if evidence.isExplaining {
                    ProgressView("Explaining on device…").font(.footnote)
                        .accessibilityIdentifier("takt.diagnose.explaining")
                } else if let explanation = evidence.explanation {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label("Apple Intelligence", systemImage: "apple.intelligence")
                            .font(.caption).foregroundStyle(Palette.textSecondary)
                        Text(explanation).font(.body).foregroundStyle(Palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("takt.diagnose.explanation")
                    }
                }
                DisclosureGroup(isExpanded: $showsLines) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(evidence.excerpt.lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(evidence.explanation == nil
                             ? "Lines most likely to show the failure, with credentials redacted."
                             : "The explanation above uses only these redacted lines. Check them before acting.")
                            .font(.caption).foregroundStyle(Palette.textSecondary)
                            .padding(.top, Spacing.xs)
                    }
                    .textSelection(.enabled)
                    .padding(.top, Spacing.sm)
                } label: {
                    Text("Key log lines (\(evidence.excerpt.lines.count))").font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.text)
                }
                .accessibilityIdentifier("takt.diagnose.lines")
            }
        }
    }
}
