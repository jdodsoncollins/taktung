import SwiftUI

struct StateWord: View {
    var label: String
    var tone: ConsoleStateTone

    var body: some View {
        Text(label)
            .font(MonoFont.body(13, weight: .semibold))
            .foregroundStyle(tone.color)
            .textCase(.uppercase)
            .monospacedDigit()
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(MonoFont.body(11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Palette.textSecondary)
    }
}

struct Plate<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.plate, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radii.plate, style: .continuous)
                    .strokeBorder(Palette.border, lineWidth: 0.5)
            )
    }
}

struct PrimaryButton: View {
    var title: String
    var role: Role = .accent
    var disabled: Bool = false
    var action: () -> Void

    enum Role {
        case accent
        case danger
        case ghost
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MonoFont.body(14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.button, style: .continuous)
                        .strokeBorder(role == .ghost ? Palette.border : .clear, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private var foreground: Color {
        switch role {
        case .accent: Palette.textOnAccent
        case .danger: .white
        case .ghost: Palette.text
        }
    }

    private var background: Color {
        switch role {
        case .accent: Palette.accent
        case .danger: Palette.danger
        case .ghost: Palette.surfaceMuted
        }
    }
}

struct FilterChip: View {
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(MonoFont.body(12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? Palette.accent : Palette.textSecondary)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Palette.accentSoft : Palette.surfaceMuted)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(selected ? Palette.accent : Palette.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
