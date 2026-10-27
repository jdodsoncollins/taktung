import SwiftUI

struct StateWord: View {
    var label: String
    var tone: ConsoleStateTone

    var body: some View {
        Label(label.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tone.color)
            .monospacedDigit()
    }

    private var symbol: String {
        switch tone {
        case .ready: "checkmark.circle.fill"
        case .building: "clock"
        case .error: "exclamationmark.circle.fill"
        case .neutral: "circle.dotted"
        }
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Palette.text)
    }
}

struct Plate<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(Spacing.lg)
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
                .font(.body.weight(.medium))
                .padding(.horizontal, Spacing.md)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.button, style: .continuous)
                        .strokeBorder(role == .accent ? .clear : Palette.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private var foreground: Color {
        switch role {
        case .accent: Palette.textOnAction
        case .danger: Palette.danger
        case .ghost: Palette.text
        }
    }

    private var background: Color {
        switch role {
        case .accent: Palette.action
        case .danger, .ghost: Palette.surface
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
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .foregroundStyle(selected ? Palette.text : Palette.textSecondary)
                .background(
                    RoundedRectangle(cornerRadius: Radii.button, style: .continuous)
                        .fill(selected ? Palette.surface : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.button, style: .continuous)
                        .strokeBorder(selected ? Palette.border : .clear, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}
