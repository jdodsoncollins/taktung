import SwiftUI

/// Wraps chips onto as many lines as they need instead of scrolling them off screen.
struct ChipFlowLayout: Layout {
    var spacing: CGFloat = Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width { x = 0; y += line + spacing; line = 0 }
            x += size.width + spacing
            line = max(line, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += line + spacing; line = 0 }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}

/// An applied filter that one tap removes, widening the results.
struct RemovableChip: View {
    var label: String
    var remove: () -> Void

    var body: some View {
        Button(action: remove) {
            HStack(spacing: Spacing.xs) {
                Text(label).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "xmark").font(.caption2.weight(.semibold)).foregroundStyle(Palette.textSecondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radii.button, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radii.button, style: .continuous).strokeBorder(Palette.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.text)
        .accessibilityLabel("\(label) filter")
        .accessibilityHint("Removes this filter")
    }
}
