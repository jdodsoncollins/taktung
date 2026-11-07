import SwiftUI

/// Two related content areas remain inside the system's usable regions.
/// Selection and analysis state live above this layout, so folding never creates a new session.
///
/// Two panes appear only where they sit side by side or straddle a fold: a regular-width space
/// that is wider than tall, or any space a Duo's fold divides. A taller-than-wide regular space
/// (iPad or an unfolded Duo held upright) would stack the panes into two half-height scroll areas,
/// clipping the first pane and leaving a gap above the second, so it gets one readable column.
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
            let layout = AdaptiveWorkspaceLayout.resolve(regularWidth: sizeClass == .regular, size: geometry.size,
                                                         foldActive: Self.foldActive(geometry))
            if layout == .twoPanes, #available(iOS 27.1, *) {
                ArrangementView {
                    pane(primary)
                } secondary: {
                    pane(secondary)
                }
                .arrangementViewStyle(.split)
            } else if layout == .twoPanes {
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
                    .frame(maxWidth: AdaptiveWorkspaceLayout.readableWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(Spacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .containerBackground(Palette.background, for: .navigation)
    }

    private static func foldActive(_ geometry: GeometryProxy) -> Bool {
        if #available(iOS 27.1, *) {
            return geometry.reservedRegions(kind: .division).contains(where: \.isActive)
        }
        return false
    }

    private func pane<Content: View>(_ content: Content) -> some View {
        ScrollView {
            content
                .frame(maxWidth: AdaptiveWorkspaceLayout.readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(Spacing.lg)
        }
    }
}

enum AdaptiveWorkspaceLayout: Equatable {
    case oneColumn, twoPanes

    static let readableWidth: CGFloat = 760

    /// A fold always divides the space, so panes follow it. Without one, panes need a regular-width
    /// space that is wider than tall; anything taller reads better as one scrolling column.
    static func resolve(regularWidth: Bool, size: CGSize, foldActive: Bool) -> AdaptiveWorkspaceLayout {
        if foldActive { return .twoPanes }
        return regularWidth && size.width > size.height ? .twoPanes : .oneColumn
    }
}
