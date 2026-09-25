import SwiftUI

enum Palette {
    static let background = Color(red: 12 / 255, green: 9 / 255, blue: 8 / 255)
    static let backgroundElevated = Color(red: 22 / 255, green: 19 / 255, blue: 16 / 255)
    static let surface = Color(red: 23 / 255, green: 20 / 255, blue: 18 / 255)
    static let surfaceMuted = Color(red: 34 / 255, green: 30 / 255, blue: 27 / 255)
    static let text = Color(red: 247 / 255, green: 241 / 255, blue: 234 / 255)
    static let textSecondary = Color(red: 247 / 255, green: 241 / 255, blue: 234 / 255).opacity(0.62)
    static let textTertiary = Color(red: 247 / 255, green: 241 / 255, blue: 234 / 255).opacity(0.58)
    static let textOnAccent = Color(red: 26 / 255, green: 20 / 255, blue: 16 / 255)
    static let accent = Color(red: 196 / 255, green: 120 / 255, blue: 74 / 255)
    static let accentSoft = Color(red: 196 / 255, green: 120 / 255, blue: 74 / 255).opacity(0.16)
    static let danger = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    static let ready = Color(red: 124 / 255, green: 222 / 255, blue: 204 / 255)
    static let building = Color(red: 255 / 255, green: 193 / 255, blue: 77 / 255)
    static let border = Color(red: 196 / 255, green: 120 / 255, blue: 74 / 255).opacity(0.35)
    static let separator = Color(red: 247 / 255, green: 241 / 255, blue: 234 / 255).opacity(0.10)
    static let progressTrack = Color(red: 196 / 255, green: 120 / 255, blue: 74 / 255).opacity(0.2)
    static let canvasWashBottom = Color(red: 42 / 255, green: 28 / 255, blue: 20 / 255)
}

enum Radii {
    static let plate: CGFloat = 6
    static let stamp: CGFloat = 4
    static let md: CGFloat = 12
    static let card: CGFloat = 16
    static let button: CGFloat = 12
}

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum ConsoleStateTone: Sendable {
    case ready
    case building
    case error
    case neutral

    var color: Color {
        switch self {
        case .ready: Palette.ready
        case .building: Palette.building
        case .error: Palette.danger
        case .neutral: Palette.textSecondary
        }
    }
}

func deploymentStateTone(_ state: DeploymentState) -> ConsoleStateTone {
    switch state {
    case .ready: .ready
    case .error, .canceled, .blocked: .error
    case .building, .queued, .initializing: .building
    default: .neutral
    }
}

func outcomeTone(_ outcome: ActivityOutcome) -> ConsoleStateTone {
    switch outcome {
    case .success: .ready
    case .failure: .error
    default: .neutral
    }
}

struct MonoFont {
    static func body(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .custom("Menlo", size: size).weight(weight)
    }
}

extension View {
    /// Navigation content otherwise sizes to its text and leaves the window black on the sides.
    /// Regular width (iPad, Split View, landscape Pro Max, inner fold) keeps a readable column.
    func taktCanvas() -> some View {
        modifier(TaktCanvasModifier())
    }
}

private struct TaktCanvasModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var width

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: width == .regular ? 760 : .infinity, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.background.ignoresSafeArea())
            .containerBackground(Palette.background, for: .navigation)
    }
}
