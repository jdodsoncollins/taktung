import SwiftUI
import Charts

struct WebAnalyticsView: View {
    @Environment(AppSession.self) private var session
    @State private var period: AnalyticsPeriod = .week
    @State private var dimension: AnalyticsDimension = .pages
    @State private var overview: AnalyticsOverview?
    @State private var overviewKey: LoadKey?
    @State private var segments: [AnalyticsSegment]?
    @State private var segmentsKey: SegmentKey?
    @State private var failure: InspectionFailure?
    @State private var segmentFailure: InspectionFailure?
    @State private var revision = UUID()
    @State private var showDailyValues = false

    private struct LoadKey: Hashable {
        var scope: InspectionScope?
        var period: AnalyticsPeriod
        var revision: UUID
    }
    private struct SegmentKey: Hashable {
        var load: LoadKey
        var window: AnalyticsWindow?
        var dimension: AnalyticsDimension
    }
    private var loadKey: LoadKey { .init(scope: session.inspectionScope, period: period, revision: revision) }
    // Invalidate rendered evidence synchronously when selection changes, before a new task starts.
    private var current: AnalyticsOverview? { overviewKey == loadKey ? overview : nil }
    private var segmentKey: SegmentKey { .init(load: loadKey, window: current?.window, dimension: dimension) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(session.selectedProject.map(siteTitle) ?? "Choose a site").font(.headline)
                    Picker("Reporting period", selection: $period) {
                        ForEach(AnalyticsPeriod.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("takt.analytics.period")
                    Text("Production traffic · completed days in UTC")
                        .font(.caption).foregroundStyle(Palette.textSecondary)
                }
                if session.inspectionScope == nil {
                    ContentUnavailableView("Choose a connected site", systemImage: "chart.xyaxis.line")
                } else if overviewKey == loadKey, let failure {
                    InspectionFailureView(failure: failure) { revision = UUID() }
                    availabilityNote
                } else if let current {
                    overviewContent(current)
                    breakdownContent
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Updated \(current.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                        Text("Vercel Web Analytics aggregates. Visitor counts across days and segments can overlap. Traffic is independent of deployment health.")
                    }.font(.caption).foregroundStyle(Palette.textSecondary)
                } else {
                    ProgressView("Loading analytics…").frame(maxWidth: .infinity).padding(.vertical, Spacing.xl)
                }
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(Spacing.lg).frame(maxWidth: .infinity)
        }
        .taktCanvas().navigationTitle("Analytics").navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") { revision = UUID() }
            }
        }
        .refreshable { revision = UUID() }
        .task(id: loadKey) { await load() }
        .task(id: segmentKey) { await loadSegments() }
        .accessibilityIdentifier("takt.analytics")
    }

    private func overviewContent(_ value: AnalyticsOverview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(value.window.label).font(.subheadline).foregroundStyle(Palette.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xl) { metric("Visitors", count: value.counts.visitors); Divider(); metric("Page views", count: value.counts.pageviews) }
                VStack(alignment: .leading, spacing: Spacing.lg) { metric("Visitors", count: value.counts.visitors); metric("Page views", count: value.counts.pageviews) }
            }.fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Daily page views").font(.headline)
            if value.days.isEmpty {
                Text("No daily traffic returned for this period.").font(.subheadline).foregroundStyle(Palette.textSecondary)
            } else {
                Chart(value.days) { day in
                    BarMark(x: .value("Day", day.date, unit: .day, calendar: utcCalendar), y: .value("Page views", day.counts.pageviews))
                        .foregroundStyle(Palette.accent).cornerRadius(3)
                        .accessibilityLabel(day.date.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day()))
                        .accessibilityValue("\(day.counts.pageviews) page views")
                }
                .chartXScale(domain: value.window.since...value.window.until)
                .chartXAxis { AxisMarks(values: .stride(by: .day, count: period == .week ? 2 : 7, calendar: utcCalendar)) { _ in
                    AxisGridLine(); AxisValueLabel(format: Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day())
                } }
                .chartYScale(domain: 0...max(1, value.days.map(\.counts.pageviews).max() ?? 1))
                .frame(height: 190)
                DisclosureGroup("Daily values", isExpanded: $showDailyValues) {
                    ForEach(value.days) { day in
                        HStack {
                            Text(day.date.formatted(Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day()))
                            Spacer()
                            Text("\(day.counts.pageviews.formatted()) views · \(day.counts.visitors.formatted()) visitors")
                        }.font(.caption).padding(.vertical, 4)
                    }
                }.font(.subheadline)
            }
            if value.counts.pageviews == 0 {
                Text("No production page views recorded in this period. Analytics must be enabled and installed on the website to collect visits.")
                    .font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(Spacing.lg).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var breakdownContent: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack {
                Text("Traffic breakdown").font(.headline)
                Spacer()
                Picker("Breakdown", selection: $dimension) {
                    ForEach(AnalyticsDimension.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.menu).accessibilityIdentifier("takt.analytics.breakdown")
            }
            if segmentsKey != segmentKey {
                ProgressView("Loading \(dimension.title.lowercased())…")
            } else if let segmentFailure {
                InspectionFailureView(failure: segmentFailure) { revision = UUID() }
            } else if let segments {
                if segments.isEmpty {
                    Text("No \(dimension.title.lowercased()) returned for this period.").foregroundStyle(Palette.textSecondary)
                } else {
                    HStack { Text(dimension.title); Spacer(); Text("Page views") }.font(.caption).foregroundStyle(Palette.textSecondary)
                    ForEach(segments) { segment in
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.lg) {
                            Text(dimension.label(segment.key)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Text(segment.counts.pageviews.formatted()).font(.body.monospacedDigit()).fixedSize()
                        }.accessibilityElement(children: .combine)
                        if segment.id != segments.last?.id { Divider() }
                    }
                    Text("Top 10 by page views. Others groups the remaining traffic.").font(.caption).foregroundStyle(Palette.textSecondary)
                }
            }
        }.padding(Spacing.lg).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var availabilityNote: some View {
        Text("Web Analytics must be enabled and installed on this project. Reporting periods depend on your Vercel plan and access. Try Last 7 days if a longer period is unavailable.")
            .font(.subheadline).foregroundStyle(Palette.textSecondary)
    }

    private func metric(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(Palette.textSecondary)
            Text(count.formatted()).font(.largeTitle.weight(.semibold)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = .gmt; return calendar
    }

    private func load() async {
        let key = loadKey
        overview = nil; overviewKey = nil; failure = nil; segments = nil; segmentsKey = nil
        guard let scope = key.scope else { return }
        do {
            let result = try await session.loadAnalytics(scope: scope, window: period.window())
            guard !Task.isCancelled, key == loadKey else { return }
            overview = result; overviewKey = key
        } catch {
            guard !Task.isCancelled, key == loadKey, session.inspectionScope == scope else { return }
            failure = InspectionFailure(error); overviewKey = key
        }
    }

    private func loadSegments() async {
        let key = segmentKey
        segments = nil; segmentsKey = nil; segmentFailure = nil
        guard let scope = key.load.scope, let window = key.window else { return }
        do {
            let result = try await session.loadAnalyticsSegments(scope: scope, dimension: key.dimension, window: window)
            guard !Task.isCancelled, key == segmentKey else { return }
            segments = result; segmentsKey = key
        } catch {
            guard !Task.isCancelled, key == segmentKey, session.inspectionScope == scope else { return }
            segmentFailure = InspectionFailure(error); segmentsKey = key
        }
    }
}
