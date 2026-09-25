import SwiftUI

/// Portrait miniature of a READY deployment. The slot stays reserved so lists do not jump.
struct DeploymentPreviewThumb: View {
    var url: String?
    var state: DeploymentState
    var variant: Variant
    @State private var image: UIImage?

    enum Variant {
        case banner, chip, detail

        var size: CGSize {
            switch self {
            case .banner, .detail: CGSize(width: 120, height: 228)
            case .chip: CGSize(width: 30, height: 48)
            }
        }

        var radius: CGFloat {
            self == .chip ? 4 : 12
        }
    }

    var body: some View {
        let size = variant.size
        ZStack {
            Palette.surfaceMuted
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height, alignment: .top)
                    .clipped()
                Color.black.opacity(0.12)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: variant.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: variant.radius, style: .continuous)
                .strokeBorder(Palette.border, lineWidth: 0.5)
        )
        .accessibilityHidden(true)
        .task(id: pageURL) {
            await load()
        }
    }

    private var pageURL: String? {
        guard shouldProbeDeploymentPreview(state: state, url: url) else { return nil }
        return absoluteDeploymentURL(url)
    }

    private func load() async {
        guard let pageURL else {
            image = nil
            return
        }
        if let cached = PreviewCaptureCenter.shared.cachedImage(for: pageURL) {
            image = cached
            return
        }
        image = await PreviewCaptureCenter.shared.image(for: pageURL, prioritize: variant != .chip)
    }
}
