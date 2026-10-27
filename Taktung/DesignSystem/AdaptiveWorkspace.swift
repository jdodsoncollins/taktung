import SwiftUI

/// Two related content areas remain inside the system's usable regions.
/// Selection and analysis state live above this layout, so folding never creates a new session.
struct AdaptiveWorkspace<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    var primary: Primary
    var secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        GeometryReader { geometry in
            if #available(iOS 27.1, *),
               sizeClass == .regular || geometry.reservedRegions(kind: .division).contains(where: \.isActive) {
                ArrangementView {
                    pane(primary)
                } secondary: {
                    pane(secondary)
                }
                .arrangementViewStyle(.split)
            } else if sizeClass == .regular {
                HStack(alignment: .top, spacing: 0) {
                    pane(primary)
                    pane(secondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        primary
                        secondary
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .containerBackground(Palette.background, for: .navigation)
    }

    private func pane<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(Spacing.lg)
        }
    }
}
