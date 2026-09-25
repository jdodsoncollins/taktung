import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var confirmDisconnect = false
    @State private var demoEnabled = DemoMode.isEnabled
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Plate {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SectionLabel(text: "Personal access token")
                        Text("Create a token at vercel.com/account/tokens. Stored only on this device (Keychain).")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        SecureField("vercel_… or account token", text: $token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(MonoFont.body(13))
                            .padding(Spacing.md)
                            .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radii.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                                    .strokeBorder(Palette.border, lineWidth: 0.5)
                            )
                            .accessibilityIdentifier(AccessibilityIDs.tokenInput)
                            .accessibilityLabel("Vercel access token")
                        PrimaryButton(
                            title: session.connection.isConnected ? "Update token" : "Connect with token",
                            disabled: session.isBusy
                        ) {
                            Task {
                                let result = await session.connectWithToken(token)
                                switch result {
                                case .connected:
                                    token = ""
                                    statusMessage = "Connected to Vercel"
                                    dismiss()
                                case .rejected(let message):
                                    statusMessage = message
                                }
                            }
                        }
                        .accessibilityIdentifier(AccessibilityIDs.connectButton)
                        if session.connection.isConnected {
                            PrimaryButton(title: "Disconnect and erase local data", role: .danger) {
                                confirmDisconnect = true
                            }
                        }
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }

                if session.connection.isConnected && !session.connection.teams.isEmpty {
                    Plate {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            SectionLabel(text: "Team")
                            PrimaryButton(
                                title: session.connection.selectedTeamId == nil
                                    ? "● Personal / default"
                                    : "Personal / default",
                                role: .ghost
                            ) {
                                Task { await session.selectTeam(nil) }
                            }
                            ForEach(session.connection.teams) { team in
                                PrimaryButton(
                                    title: session.connection.selectedTeamId == team.id
                                        ? "● \(team.name) (\(team.slug))"
                                        : "\(team.name) (\(team.slug))",
                                    role: .ghost
                                ) {
                                    Task { await session.selectTeam(team.id) }
                                }
                            }
                        }
                    }
                }

                Plate {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SectionLabel(text: "Screenshot demo")
                        Text("Loads fixture sites for App Store screenshots. Live Vercel is disabled while this is on.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        Toggle("Screenshot demo", isOn: $demoEnabled)
                            .tint(Palette.accent)
                            .accessibilityIdentifier(AccessibilityIDs.demoToggle)
                            .onChange(of: demoEnabled) { _, enabled in
                                Task { await session.enableDemo(enabled) }
                            }
                    }
                }

                Plate {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SectionLabel(text: "About")
                        Text("Taktung translates from German as putting work on a beat. The name is a reference to ZEIT, Vercel’s original name.\nTaktung is a local-first Vercel operations assistant. It is not affiliated with Vercel in any way.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.accent)
                        Text("My other apps:")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        Link(destination: AppConfig.otherAppStoreURL) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(AppConfig.otherAppName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Palette.accent)
                                Text(AppConfig.otherAppBlurb)
                                    .font(.footnote)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Palette.accent)
            }
        }
        .confirmationDialog(
            "Disconnect and erase local data?",
            isPresented: $confirmDisconnect,
            titleVisibility: .visible
        ) {
            Button("Disconnect and erase", role: .destructive) {
                Task { await session.disconnect() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes Vercel credentials, team and project selections, and all local activity from this device.")
        }
    }
}
