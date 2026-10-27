import SwiftUI
import UIKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "taktung.appearance"
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum Palette {
    static let canvas = adaptive(light: 0xF5F6F8, dark: 0x111416)
    static let background = Color(uiColor: canvas)
    static let backgroundElevated = Color(uiColor: .secondarySystemGroupedBackground)
    static let surface = Color(uiColor: adaptive(light: 0xFFFFFF, dark: 0x1B1F22))
    static let surfaceMuted = Color(uiColor: adaptive(light: 0xEEF0F2, dark: 0x272C30))
    static let text = Color.primary
    static let textSecondary = Color(uiColor: adaptive(light: 0x59636B, dark: 0xACB6BD))
    static let textTertiary = textSecondary
    static let action = Color(uiColor: adaptive(light: 0x263237, dark: 0xE3E9EB))
    static let textOnAction = Color(uiColor: adaptive(light: 0xFFFFFF, dark: 0x182125))
    static let textOnAccent = Color(uiColor: adaptive(light: 0xFFFFFF, dark: 0x112D2A))
    static let accent = Color(uiColor: adaptive(light: 0x146B65, dark: 0x7BD6CD))
    static let accentSoft = Color(uiColor: adaptive(light: 0xE4F0EE, dark: 0x223B38))
    static let danger = Color(uiColor: adaptive(light: 0xB42318, dark: 0xFFABA3))
    static let ready = Color(uiColor: adaptive(light: 0x23734F, dark: 0x8BD9AF))
    static let building = Color(uiColor: adaptive(light: 0x8A5A08, dark: 0xEDC47C))
    static let border = Color(uiColor: .separator)
    static let separator = border

    private static func adaptive(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
    }
}

enum Radii {
    static let plate: CGFloat = 12
    static let stamp: CGFloat = 4
    static let md: CGFloat = 12
    static let card: CGFloat = 16
    static let button: CGFloat = 8
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
        .custom("Menlo", size: size, relativeTo: size <= 12 ? .caption : .subheadline).weight(weight)
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
