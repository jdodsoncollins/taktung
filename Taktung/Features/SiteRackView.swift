import SwiftUI

struct SiteRackView: View {
    @Environment(\.dynamicTypeSize) private var textSize
    var project: VercelProject

    var body: some View {
        let production = project.productionDeployment
        VStack(alignment: .leading, spacing: Spacing.md) {
            if textSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Production").font(.title2.weight(.semibold))
                    productionState
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Production").font(.title2.weight(.semibold))
                    Spacer(minLength: Spacing.sm)
                    productionState
                }
            }
            Plate {
                HStack(alignment: .top, spacing: Spacing.lg) {
                    if !textSize.isAccessibilitySize, production?.state == .ready {
                        DeploymentPreviewThumb(url: production?.url, state: production?.state ?? .unknown, variant: .summary)
                    }
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if let production {
                            Text(deploymentTitle(production))
                                .font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                            Label(siteStampProd(project), systemImage: "arrow.triangle.branch")
                                .font(.subheadline).foregroundStyle(Palette.textSecondary)
                            let age = formatCompactAge(production.createdAt)
                            if textSize.isAccessibilitySize {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text(shortSha(production)).font(MonoFont.body())
                                    Text(age == "now" ? "Just now" : "\(age) ago").font(.caption)
                                }.foregroundStyle(Palette.textSecondary)
                            } else {
                                HStack(spacing: Spacing.sm) {
                                    Text(shortSha(production)).font(MonoFont.body())
                                    Text(age == "now" ? "· Just now" : "· \(age) ago").font(.caption)
                                }.foregroundStyle(Palette.textSecondary)
                            }
                        } else {
                            Text("No production deployment").font(.body.weight(.medium))
                            Text("Open Deploys to inspect this site's builds.")
                                .font(.subheadline).foregroundStyle(Palette.textSecondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.foregroundStyle(Palette.text)
    }

    private var productionState: some View {
        StateWord(label: project.productionDeployment?.state.rawValue ?? "Not deployed",
                  tone: deploymentStateTone(project.productionDeployment?.state ?? .unknown))
    }
}
