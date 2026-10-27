import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @State private var token = ""
    @State private var confirmDisconnect = false
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                HStack(alignment: .center, spacing: Spacing.lg) {
                    Image("TaktungMark").resizable().frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppConfig.displayName).font(.headline)
                        Text("Vercel release inspection").font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }
                }.padding(.vertical, Spacing.sm)
            }
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("takt.settings.appearance")
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows your device's light or dark appearance.")
            }
            Section {
                SecureField("Personal access token", text: $token,
                            prompt: Text("Personal access token").foregroundStyle(Palette.textSecondary))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier(AccessibilityIDs.tokenInput)
                    .accessibilityLabel("Vercel access token")
                Button(session.connection.isConnected ? "Update token" : "Connect to Vercel") {
                    Task {
                        switch await session.connectWithToken(token) {
                        case .connected:
                            token = ""
                            statusMessage = "Connected to Vercel"
                            dismiss()
                        case .rejected(let message): statusMessage = message
                        }
                    }
                }
                .disabled(session.isBusy || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier(AccessibilityIDs.connectButton)
                if let statusMessage { Text(statusMessage).font(.footnote).foregroundStyle(Palette.textSecondary) }
                Link("Create a token on Vercel", destination: URL(string: "https://vercel.com/account/tokens")!)
            } header: {
                Text("Vercel account")
            } footer: {
                Text("Your token is stored in the Keychain on this device.")
            }
            if session.connection.isConnected && !session.connection.teams.isEmpty {
                Section("Workspace") {
                    Picker("Team", selection: Binding(
                        get: { session.connection.selectedTeamId ?? "" },
                        set: { value in Task { await session.selectTeam(value.isEmpty ? nil : value) } }
                    )) {
                        Text("Personal").tag("")
                        ForEach(session.connection.teams) { team in Text(team.name).tag(team.id) }
                    }.disabled(session.isBusy)
                }
            }
            if session.onDeviceAvailable {
                Section("On-device summaries") {
                    Label("Apple Intelligence available", systemImage: "apple.intelligence")
                    Text("Site health summaries use only the loaded snapshot and stay on this device.")
                        .font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
            }
            Section("Home Screen widgets") {
                Label("Deployment status", systemImage: "square.grid.2x2")
                Text("Add a small, medium or large Taktung widget from the Home Screen widget gallery. The large widget adds recent deployment activity. Widgets show all projects by default. Touch and hold a widget, then choose Edit Widget to filter by project. iOS schedules updates; the checked time shows freshness.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
            Section("Siri & Shortcuts") {
                Link("Open Shortcuts", destination: URL(string: "shortcuts://")!)
                Text("Ask Siri to check deploy status in Taktung. In Shortcuts, choose a project for deployment status, inspection or site health. An empty project uses all projects for status and your current site for inspection. Site health explains loaded signals; it does not probe website uptime.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
            Section("About") {
                Text("Taktung helps you inspect Vercel deployments, follow website traffic, compare changes and keep a local record of your checks.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                NavigationLink("Tip Jar", value: SettingsDestination.tipJar)
                    .accessibilityIdentifier("takt.settings.tipJar")
                NavigationLink("Other Apps", value: SettingsDestination.otherApps)
                    .accessibilityIdentifier("takt.settings.otherApps")
                Text("Taktung means putting work on a beat. The name refers to ZEIT, Vercel's original name.")
                    .font(.caption).foregroundStyle(Palette.textSecondary)
                Text("Taktung is independent and is not affiliated with Vercel.")
                    .font(.caption).foregroundStyle(Palette.textSecondary)
            }
            if session.hasLocalAccountData {
                Section {
                    Button("Disconnect and erase local data", role: .destructive) { confirmDisconnect = true }
                        .disabled(session.historyIsBusy)
                }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .taktCanvas().navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
        // Register destinations outside List's lazy cells so iPad focus restoration
        // keeps a stable navigation owner when returning to the scrolled Settings.
        .navigationDestination(for: SettingsDestination.self) { destination in
            switch destination {
            case .tipJar: TipJarView()
            case .otherApps: OtherAppsView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", systemImage: "checkmark") { dismiss() }
            }
        }
        .confirmationDialog("Disconnect and erase local data?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Disconnect and erase", role: .destructive) { Task { await session.disconnect() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes Vercel credentials, team and project selections, and this account's activity, notes, and saved visual baselines from this device.")
        }
    }

}

private enum SettingsDestination: Hashable {
    case tipJar
    case otherApps
}

struct OtherAppsView: View {
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        List {
            ForEach(AppConfig.otherApps) { app in
                Section {
                Link(destination: app.detailURL) {
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        if !textSize.isAccessibilitySize {
                            Image(app.icon).resizable().frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(app.name).font(.headline).foregroundStyle(Palette.text)
                            Text(app.detail).font(.body).foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.subheadline).foregroundStyle(Palette.textSecondary)
                    }.padding(.vertical, Spacing.md)
                }.accessibilityHint("Opens the app’s details on Jeremy Collins’ website")
                Link("View on the App Store", destination: app.storeURL).font(.subheadline)
                }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden).taktCanvas()
            .navigationTitle("Other Apps").navigationBarTitleDisplayMode(.large)
    }
}
