import SwiftUI

struct SiteRackView: View {
    var project: VercelProject

    var body: some View {
        let prod = project.productionDeployment
        let clear = siteClearWord(project)
        let age = siteStampAge(project)
        let prodLabel = siteStampProd(project)
        let git = siteStampGit(project)
        let state = prod?.state ?? .unknown
        let stateTone = deploymentStateTone(state)

        VStack(alignment: .leading, spacing: Spacing.sm) {
            Plate {
                HStack {
                    Spacer(minLength: 0)
                    DeploymentPreviewThumb(
                        url: prod?.url,
                        state: prod?.state ?? .unknown,
                        variant: .banner
                    )
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Spacing.sm)
            }

            Plate {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        StateWord(label: clear.label, tone: clear.tone)
                        Text("·")
                            .font(MonoFont.body(13, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                        StateWord(label: state.rawValue, tone: stateTone)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.progressTrack)
                            Capsule()
                                .fill(Palette.accent)
                                .frame(width: max(2, geo.size.width * age.fill))
                        }
                    }
                    .frame(height: 3)
                    HStack(alignment: .top, spacing: Spacing.md) {
                        stampCell("PROD", prodLabel)
                        stampCell("GIT", git)
                        stampCell("AGE", age.label)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(clear.label). \(state.rawValue). \(prodLabel). \(git). \(age.label).")
    }

    private func stampCell(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(key)
                .font(MonoFont.body(11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Palette.accent)
            Text(value)
                .font(MonoFont.body(13, weight: .semibold))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
