import SwiftUI
import WidgetKit

struct DeploymentEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetDeploymentSnapshot?
    var cached = false
    var message: String?
}

struct DeploymentProvider: AppIntentTimelineProvider {
    let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> DeploymentEntry {
        DeploymentEntry(date: Date(), snapshot: .gallery())
    }

    func snapshot(for configuration: DeploymentWidgetConfiguration, in context: Context) async -> DeploymentEntry {
        context.isPreview ? placeholder(in: context) : storedEntry(projectID: selection(configuration))
    }

    func timeline(for configuration: DeploymentWidgetConfiguration, in context: Context) async -> Timeline<DeploymentEntry> {
        let entry = await refreshedEntry(projectID: selection(configuration))
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    private func selection(_ configuration: DeploymentWidgetConfiguration) -> String {
        configuration.project?.id ?? WidgetAccountContext.allProjectsID
    }

    private func storedEntry(projectID: String) -> DeploymentEntry {
        guard let context = widgetAccountContext(store: store) else {
            return DeploymentEntry(date: Date(), message: "Open Taktung and connect to Vercel.")
        }
        guard context.name(for: projectID) != nil else {
            return DeploymentEntry(date: Date(), message: "Project unavailable. Choose a project in Edit Widget.")
        }
        guard let snapshot = store.cachedSnapshot(for: context, projectID: projectID)
                ?? context.cachedSnapshots.first(where: { $0.projectID == projectID }) else {
            return DeploymentEntry(date: Date(), message: "Open Taktung to refresh deployment status.")
        }
        return DeploymentEntry(date: Date(), snapshot: snapshot, cached: context.source == .live)
    }

    private func refreshedEntry(projectID: String) async -> DeploymentEntry {
        let initial = storedEntry(projectID: projectID)
        guard let context = widgetAccountContext(store: store), context.source == .live,
              let seed = context.seed(for: projectID), let token = store.token() else { return initial }
        do {
            let refreshed = try await WidgetDeploymentService().refresh(seed, token: token)
            guard let current = store.load(), current.isSameScope(as: context),
                  current.name(for: projectID) != nil, store.token() == token else {
                return storedEntry(projectID: projectID)
            }
            store.saveCache(refreshed)
            return DeploymentEntry(date: Date(), snapshot: refreshed)
        } catch WidgetDeploymentService.Failure.unauthorized {
            guard let current = store.load(), current.isSameScope(as: context), store.token() == token else {
                return storedEntry(projectID: projectID)
            }
            return DeploymentEntry(date: Date(), message: "Open Taktung to reconnect.")
        } catch { return storedEntry(projectID: projectID) }
    }
}

@main
struct TaktungDeploymentWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: AppConfig.widgetKind, intent: DeploymentWidgetConfiguration.self, provider: DeploymentProvider()) { entry in
            DeploymentWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetGround() }
                .widgetURL(URL(string: "\(AppConfig.urlScheme)://deploys"))
        }
        .configurationDisplayName("Deployment status")
        .description("Latest deployment, recent counts and activity. Show all projects or filter by project in Edit Widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DeploymentWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var entry: DeploymentEntry

    private var accent: Color {
        renderingMode == .fullColor
            ? (colorScheme == .dark ? Color(red: 0.48, green: 0.84, blue: 0.80) : Color(red: 0.08, green: 0.42, blue: 0.40))
            : .primary
    }

    // Secondary system label can fall below 4.5:1 on WidgetKit's light ground.
    private var secondaryText: Color { .primary.opacity(0.75) }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if family == .systemLarge {
                    largeContent(snapshot).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                } else if dynamicTypeSize.isAccessibilitySize {
                    accessibleContent(snapshot)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                } else { content(snapshot) }
            }
            else { empty }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .privacySensitive()
    }

    private func content(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 8) {
            scopeHeader(snapshot)
            if family == .systemSmall {
                latest(snapshot)
                Spacer(minLength: 0)
                stats(snapshot)
            } else {
                HStack(alignment: .center, spacing: 14) {
                    latest(snapshot).frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(.quaternary).frame(width: 1, height: 45)
                    stats(snapshot).frame(maxWidth: .infinity)
                }
                Spacer(minLength: 0)
            }
            freshness(snapshot)
        }
    }

    private func scopeHeader(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        HStack(spacing: 5) {
            Text(snapshot.projectName).font(.subheadline.weight(.semibold))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
            if snapshot.source == .demo, family != .systemSmall {
                Text("Demo").font(.caption2).foregroundStyle(secondaryText)
            } else if snapshot.source == .live {
                Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                    .foregroundStyle(accent).accessibilityHidden(true)
            }
        }
    }

    private func largeContent(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            scopeHeader(snapshot)
            HStack(alignment: .center, spacing: 14) {
                latest(snapshot).frame(maxWidth: .infinity, alignment: .leading)
                stats(snapshot).frame(maxWidth: .infinity)
            }
            Divider()
            Text("Recent deploys").font(.caption.weight(.semibold))
            if snapshot.events.isEmpty {
                Text(snapshot.total == 0 ? "No deploys yet." : "Open Taktung to refresh recent activity.")
                    .font(.caption).foregroundStyle(secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.events.prefix(dynamicTypeSize.isAccessibilitySize ? 3 : 5), id: \.id) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(event.projectName ?? snapshot.projectName).font(.caption.weight(.medium))
                                    .lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 0)
                                Label(statusLabel(event.state), systemImage: statusSymbol(event.state))
                                    .font(.caption2.weight(.medium)).foregroundStyle(statusColor(event.state))
                            }
                            HStack(spacing: 4) {
                                if let target = event.target { Text(target.rawValue.capitalized); Text("·") }
                                Text(compactTime(event.createdAt))
                            }.font(.caption2).foregroundStyle(secondaryText)
                        }.accessibilityElement(children: .combine)
                            .accessibilityValue(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            Spacer(minLength: 0)
            freshness(snapshot)
        }
    }

    private func latest(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if snapshot.projectID == WidgetAccountContext.allProjectsID, let name = snapshot.latest?.projectName {
                    Text(name)
                } else { Text("Latest deploy") }
            }.font(.caption2).foregroundStyle(secondaryText).lineLimit(1).truncationMode(.middle)
            if let latest = snapshot.latest {
                Label(statusLabel(latest.state), systemImage: statusSymbol(latest.state))
                    .font(.title3.weight(.semibold)).labelStyle(.titleAndIcon)
                    .foregroundStyle(statusColor(latest.state)).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    if family != .systemSmall, let target = latest.target {
                        Text(target.rawValue.capitalized)
                        Text("·")
                    }
                    Text(compactTime(latest.createdAt))
                        .accessibilityLabel(latest.createdAt.formatted(date: .abbreviated, time: .shortened))
                }.font(.caption2).foregroundStyle(secondaryText).lineLimit(1).minimumScaleFactor(0.8)
            } else {
                Text("No deploys yet").font(.subheadline.weight(.medium))
            }
        }.accessibilityElement(children: .combine)
    }

    private func stats(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        HStack(alignment: .top, spacing: 6) {
            stat(snapshot.ready, label: "Ready")
            Spacer(minLength: 0)
            stat(snapshot.failed, label: "Failed")
            Spacer(minLength: 0)
            stat(snapshot.building, label: "Building")
        }.accessibilityLabel("Recent \(snapshot.total) deployments: \(snapshot.ready) ready, \(snapshot.failed) failed, \(snapshot.building) building or queued")
    }

    private func stat(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value, format: .number).font(family == .systemSmall ? .subheadline.weight(.semibold) : .title2.weight(.semibold))
                .monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(secondaryText).lineLimit(1)
        }.fixedSize(horizontal: true, vertical: false)
    }

    private func freshness(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        HStack(spacing: 3) {
            Text(freshnessText(snapshot))
            if family != .systemSmall {
                Spacer(minLength: 0)
                Text("Recent \(snapshot.total)")
            }
        }.font(.caption2).foregroundStyle(secondaryText).lineLimit(1)
            .accessibilityLabel(freshnessAccessibility(snapshot))
    }

    /// Fixed-size widgets prioritize readable state and counts at accessibility sizes.
    /// Stack count labels instead of squeezing three columns; keep full evidence for VoiceOver.
    private func accessibleContent(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.projectName).font(.caption.weight(.semibold))
                .lineLimit(1).truncationMode(.middle)
            if family == .systemSmall {
                accessibleStatus(snapshot)
                accessibleStats(snapshot)
            } else {
                HStack(spacing: 12) {
                    accessibleStatus(snapshot).frame(maxWidth: .infinity, alignment: .leading)
                    accessibleStats(snapshot).frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
            Text(freshnessText(snapshot)).font(.caption2).foregroundStyle(secondaryText).lineLimit(1)
                .accessibilityLabel(freshnessAccessibility(snapshot))
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("Recent \(snapshot.total) deployments. Checked \(snapshot.checkedAt.formatted(date: .abbreviated, time: .shortened)).")
    }

    private func accessibleStatus(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        Group {
            if let latest = snapshot.latest {
                Label(statusLabel(latest.state), systemImage: statusSymbol(latest.state))
                    .font(.headline).foregroundStyle(statusColor(latest.state))
            } else { Text("No deploys yet").font(.subheadline) }
        }.lineLimit(1).minimumScaleFactor(0.85)
    }

    private func accessibleStats(_ snapshot: WidgetDeploymentSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            accessibleStat(snapshot.ready, label: "Ready")
            accessibleStat(snapshot.failed, label: "Failed")
            accessibleStat(snapshot.building, label: "Building")
        }.font(.caption2)
    }

    private func accessibleStat(_ value: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(secondaryText)
            Spacer(minLength: 0)
            Text(value, format: .number).fontWeight(.semibold).monospacedDigit()
        }
    }

    private func freshnessText(_ snapshot: WidgetDeploymentSnapshot) -> String {
        let cached = entry.cached || entry.date.timeIntervalSince(snapshot.checkedAt) > 3_600
        let prefix = snapshot.source == .demo && (family == .systemSmall || dynamicTypeSize.isAccessibilitySize)
            ? "Demo" : (cached ? "Cached" : "Checked")
        // Clock time is stable between system-scheduled updates. Show date for earlier days.
        return "\(prefix) · \(compactTime(snapshot.checkedAt))"
    }

    private func compactTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = Calendar.current.isDate(date, inSameDayAs: entry.date) ? "HH:mm" : "MMM d"
        return formatter.string(from: date)
    }

    private func freshnessAccessibility(_ snapshot: WidgetDeploymentSnapshot) -> String {
        let cached = entry.cached || entry.date.timeIntervalSince(snapshot.checkedAt) > 3_600
        return "\(snapshot.source == .demo ? "Demo. " : "")\(cached ? "Cached data. " : "")Checked \(snapshot.checkedAt.formatted(date: .abbreviated, time: .shortened))."
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(AppConfig.displayName, systemImage: "arrow.up.right").font(.headline).foregroundStyle(accent)
            Text("Deployment status").font(.subheadline.weight(.semibold))
            Text(entry.message ?? "Open Taktung and choose a site.").font(.caption).foregroundStyle(secondaryText)
        }
    }

    private func statusLabel(_ state: DeploymentState) -> String {
        switch state {
        case .ready: "Ready"
        case .error: "Failed"
        case .blocked: "Blocked"
        case .canceled: "Canceled"
        case .building: "Building"
        case .initializing: "Starting"
        case .queued: "Queued"
        case .deleted: "Deleted"
        case .unknown: "Unknown"
        }
    }

    private func statusSymbol(_ state: DeploymentState) -> String {
        switch state {
        case .ready: "checkmark.circle.fill"
        case .error, .blocked: "exclamationmark.circle.fill"
        case .canceled, .deleted: "xmark.circle"
        case .building, .initializing, .queued: "clock"
        case .unknown: "questionmark.circle"
        }
    }

    private func statusColor(_ state: DeploymentState) -> Color {
        guard renderingMode == .fullColor else { return .primary }
        switch state {
        case .ready: return accent
        case .error, .blocked: return colorScheme == .dark ? Color(red: 1, green: 0.67, blue: 0.64) : Color(red: 0.70, green: 0.14, blue: 0.09)
        case .building, .initializing, .queued: return colorScheme == .dark ? Color(red: 0.93, green: 0.77, blue: 0.49) : Color(red: 0.54, green: 0.35, blue: 0.03)
        default: return secondaryText
        }
    }
}

private struct WidgetGround: View {
    var body: some View {
        Color(.secondarySystemBackground)
    }
}

#Preview("Small", as: .systemSmall) { TaktungDeploymentWidget() } timeline: {
    DeploymentEntry(date: Date(), snapshot: .gallery())
}
#Preview("Medium", as: .systemMedium) { TaktungDeploymentWidget() } timeline: {
    DeploymentEntry(date: Date(), snapshot: .gallery())
}
#Preview("Large", as: .systemLarge) { TaktungDeploymentWidget() } timeline: {
    DeploymentEntry(date: Date(), snapshot: .gallery())
}
