import SwiftUI
import Observation

/// Owned above AdaptiveWorkspace, so folding changes layout without discarding review evidence.
@Observable
final class VisualComparisonState {
    fileprivate var routeText = "/"
    fileprivate var referenceID = ""
    fileprivate var saved: VisualCapture?
    fileprivate var baseline: VisualCapture?
    fileprivate var candidate: VisualCapture?
    fileprivate var request: VisualComparisonRequest?
    fileprivate var busy = false
    fileprivate var message: String?
    fileprivate var mode: ComparisonPresentation = .reveal
    fileprivate var reveal = 0.5
    fileprivate var confirmBaseline = false
    fileprivate var expanded: ComparisonPair?
    fileprivate var loadedContext: String?
}

fileprivate struct VisualComparisonRequest: Identifiable {
    let id = UUID()
    var context: String
    var scope: EvidenceScope
    var projectID: ProjectID
    var route: String
    var reference: VercelDeploymentSummary?
    var saved: VisualCapture?
}

struct VisualComparisonView: View {
    @Environment(AppSession.self) private var session
    var deployment: VercelDeploymentSummary
    @Bindable var comparison: VisualComparisonState

    private var routeText: String { comparison.routeText }
    private var referenceID: String { get { comparison.referenceID } nonmutating set { comparison.referenceID = newValue } }
    private var saved: VisualCapture? { get { comparison.saved } nonmutating set { comparison.saved = newValue } }
    private var baseline: VisualCapture? { get { comparison.baseline } nonmutating set { comparison.baseline = newValue } }
    private var candidate: VisualCapture? { get { comparison.candidate } nonmutating set { comparison.candidate = newValue } }
    private var request: VisualComparisonRequest? { get { comparison.request } nonmutating set { comparison.request = newValue } }
    private var busy: Bool { get { comparison.busy } nonmutating set { comparison.busy = newValue } }
    private var message: String? { get { comparison.message } nonmutating set { comparison.message = newValue } }
    private var mode: ComparisonPresentation { comparison.mode }
    private var reveal: Double { comparison.reveal }
    private var confirmBaseline: Bool { get { comparison.confirmBaseline } nonmutating set { comparison.confirmBaseline = newValue } }
    private var expanded: ComparisonPair? { get { comparison.expanded } nonmutating set { comparison.expanded = newValue } }

    private var context: String {
        "\(session.evidenceScope?.accountID ?? "")|\(session.evidenceScope?.teamID ?? "")|\(session.evidenceScope?.isDemo ?? false)|\(session.selectedProjectId ?? "")|\(deployment.id)"
    }

    private var references: [VercelDeploymentSummary] {
        guard let project = session.selectedProject else { return [] }
        return comparisonBaselines(project: project, deployments: session.deployments, candidateID: deployment.id)
    }

    private var candidateBelongsToSite: Bool {
        session.selectedProject != nil && session.deployments.contains { $0.id == deployment.id }
    }

    var body: some View {
        Plate {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionLabel(text: "Visual comparison")
                if !candidateBelongsToSite {
                    Text("The selected site changed. Open a deployment from the current site to compare it.")
                        .foregroundStyle(Palette.textSecondary)
                } else if deployment.state != .ready {
                    Text("Only READY deployments can be captured. Choose a successful deployment to review its page.")
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    controls
                    if busy { ProgressView("Capturing pages…").frame(maxWidth: .infinity) }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(Palette.textSecondary)
                            .accessibilityIdentifier("takt.compare.message")
                    }
                    if let baseline, let candidate {
                        comparisonContent(baseline: baseline, candidate: candidate)
                    } else if let saved {
                        Text("Saved baseline: \(saved.commit) · \(saved.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote).foregroundStyle(Palette.textSecondary)
                    }
                    Text("390 × 844 · light appearance · top of page. Captures are a visual review, not a test of page interactions.")
                        .font(.caption).foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .task(id: context + "|" + routeText) { await loadSavedBaseline() }
        .onChange(of: referenceID) { _, _ in
            if !busy { baseline = nil; candidate = nil }
        }
        .task(id: request?.id) {
            if let request { await capture(request) }
        }
        .onDisappear { request = nil; busy = false }
        .confirmationDialog("Save this candidate as the baseline?", isPresented: $comparison.confirmBaseline, titleVisibility: .visible) {
            Button("Save baseline") { Task { await saveBaseline() } }
        } message: {
            Text("The saved image for this site's path will be replaced. Future comparisons use this image until you save another baseline.")
        }
        .sheet(item: $comparison.expanded) { pair in
            ComparisonReviewSheet(pair: pair)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            TextField("Page path", text: $comparison.routeText)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(MonoFont.body(14)).padding(Spacing.sm)
                .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radii.md))
                .accessibilityLabel("Page path").accessibilityIdentifier("takt.compare.route")
                .disabled(busy)
                .onSubmit { Task { await loadSavedBaseline() } }
            VStack(alignment: .leading, spacing: 4) {
                Text("Reference").font(.subheadline)
                Picker("Reference", selection: $comparison.referenceID) {
                    if saved != nil { Text("Saved baseline").tag("saved") }
                    if saved == nil && references.isEmpty { Text("No baseline yet").tag("") }
                    ForEach(references) { ref in
                        Text("\(ref.target == .production ? "Production" : "Preview") · \(shortSha(ref))").tag(ref.id)
                    }
                }
                .pickerStyle(.menu).disabled(busy)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("takt.compare.reference")
            }
            PrimaryButton(title: candidate == nil ? "Capture comparison" : "Recapture pages", disabled: busy) {
                Task { await beginCapture() }
            }
            .accessibilityIdentifier("takt.compare.capture")
        }
    }

    private func comparisonContent(baseline: VisualCapture, candidate: VisualCapture) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Picker("Comparison view", selection: $comparison.mode) {
                ForEach(ComparisonPresentation.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            ComparisonCanvas(baseline: baseline, candidate: candidate, mode: mode, reveal: $comparison.reveal)
            if mode == .reveal {
                Slider(value: $comparison.reveal, in: 0...1) { Text("Reveal baseline") }
                    .accessibilityValue("\(Int(reveal * 100)) percent baseline")
                    .accessibilityIdentifier("takt.compare.slider")
            }
            CaptureStamp(title: "Baseline", capture: baseline)
            CaptureStamp(title: "Candidate", capture: candidate)
            if baseline.deploymentID == candidate.deploymentID {
                Text("Both images are from the same deployment.")
                    .font(.footnote).foregroundStyle(Palette.textSecondary)
            }
            HStack {
                Button("Expand", systemImage: "arrow.up.left.and.arrow.down.right") {
                    expanded = ComparisonPair(baseline: baseline, candidate: candidate)
                }
                Spacer()
                Button("Save candidate baseline", systemImage: "bookmark") { confirmBaseline = true }
                    .disabled(busy).accessibilityIdentifier("takt.compare.save")
            }
            .font(.subheadline)
        }
    }

    private func loadSavedBaseline() async {
        let expected = context + "|" + routeText
        guard comparison.loadedContext != expected else { return }
        request = nil
        busy = false
        baseline = nil
        candidate = nil
        saved = nil
        message = nil
        guard let scope = session.evidenceScope, let projectID = session.selectedProjectId else { return }
        do {
            let route = try comparisonRoute(routeText)
            let value = try await session.evidenceStore.loadBaseline(scope: scope, projectID: projectID, route: route)
            guard context + "|" + routeText == expected, !Task.isCancelled else { return }
            comparison.loadedContext = expected
            saved = value
            referenceID = value != nil ? "saved" : (references.first?.id ?? "")
        } catch {
            guard context + "|" + routeText == expected, !Task.isCancelled else { return }
            comparison.loadedContext = expected
            referenceID = references.first?.id ?? ""
            message = error.localizedDescription
        }
    }

    private func beginCapture() async {
        guard !busy, candidateBelongsToSite, let scope = session.evidenceScope, let projectID = session.selectedProjectId else { return }
        let expected = context
        let expectedRoute = routeText
        request = nil
        busy = true
        defer { if request == nil, context == expected { busy = false } }
        do {
            let route = try comparisonRoute(routeText)
            let stored = try await session.evidenceStore.loadBaseline(scope: scope, projectID: projectID, route: route)
            guard context == expected, routeText == expectedRoute, !Task.isCancelled else { return }
            saved = stored
            var ref = references.first { $0.id == referenceID }
            if referenceID == "saved", stored == nil { ref = references.first }
            request = VisualComparisonRequest(context: expected, scope: scope, projectID: projectID, route: route,
                                     reference: ref, saved: referenceID == "saved" ? stored : nil)
        } catch { if context == expected, routeText == expectedRoute { message = error.localizedDescription } }
    }

    private func capture(_ input: VisualComparisonRequest) async {
        busy = true
        message = nil
        candidate = nil
        baseline = nil
        defer { if request?.id == input.id { busy = false } }
        do {
            let current = try await VisualCaptureHostRegistry.shared.capture(deployment: deployment, projectID: input.projectID, route: input.route)
            try Task.checkCancellation()
            let reference: VisualCapture?
            if let saved = input.saved { reference = saved }
            else if let ref = input.reference {
                reference = try await VisualCaptureHostRegistry.shared.capture(deployment: ref, projectID: input.projectID, route: input.route)
            } else { reference = nil }
            guard context == input.context, (try? comparisonRoute(routeText)) == input.route,
                  request?.id == input.id, !Task.isCancelled else { return }
            candidate = current
            if let reference {
                baseline = reference
                await session.recordComparison(title: "Visual comparison captured",
                    detail: "\(input.route) · baseline \(reference.commit) → candidate \(current.commit). 390 × 844; manual visual review.",
                    projectID: input.projectID, deploymentID: deployment.id, scope: input.scope)
            } else {
                // The first successful deployment can establish a baseline without inventing a reference image.
                baseline = current
                message = "No earlier READY deployment is available. Save this capture as the first baseline."
            }
        } catch is CancellationError { return }
        catch {
            guard context == input.context, request?.id == input.id else { return }
            message = error.localizedDescription
        }
    }

    private func saveBaseline() async {
        guard let candidate, let scope = session.evidenceScope,
              candidate.projectID == session.selectedProjectId, candidateBelongsToSite, !busy else { return }
        let expected = context
        busy = true
        defer { if context == expected { busy = false } }
        do {
            try await session.evidenceStore.saveBaseline(candidate, scope: scope)
            guard context == expected else { return }
            saved = candidate
            baseline = candidate
            referenceID = "saved"
            message = "Baseline saved on this device."
            await session.recordComparison(title: "Visual baseline saved",
                detail: "\(candidate.route) · \(candidate.commit) · captured \(candidate.capturedAt.formatted(date: .abbreviated, time: .shortened)).",
                projectID: candidate.projectID, deploymentID: candidate.deploymentID, scope: scope)
        } catch { if context == expected { message = error.localizedDescription } }
    }
}

enum ComparisonPresentation: String, CaseIterable, Identifiable {
    case reveal, sideBySide
    var id: String { rawValue }
    var label: String { self == .reveal ? "Reveal" : "Side by side" }
}

fileprivate struct ComparisonPair: Identifiable {
    let id = UUID()
    var baseline: VisualCapture
    var candidate: VisualCapture
}

struct ComparisonCanvas: View {
    var baseline: VisualCapture
    var candidate: VisualCapture
    var mode: ComparisonPresentation
    @Binding var reveal: Double

    var body: some View {
        if let before = UIImage(data: baseline.png), let after = UIImage(data: candidate.png) {
            GeometryReader { geometry in
                let width = geometry.size.width
                if mode == .sideBySide {
                    HStack(alignment: .top, spacing: 8) {
                        image(before, label: "Baseline page")
                        image(after, label: "Candidate page")
                    }
                } else {
                    ZStack(alignment: .topLeading) {
                        image(after, label: "Candidate page")
                        image(before, label: "Baseline page")
                            .mask(alignment: .leading) { Rectangle().frame(width: width * reveal) }
                        Rectangle().fill(Palette.accent).frame(width: 2)
                            .offset(x: width * reveal)
                        Image(systemName: "arrow.left.and.right")
                            .font(.body.weight(.semibold)).foregroundStyle(Palette.textOnAccent)
                            .frame(width: 44, height: 44).background(Palette.accent, in: Circle())
                            .position(x: max(22, min(width - 22, width * reveal)), y: geometry.size.height / 2)
                            .gesture(DragGesture(coordinateSpace: .named("visualComparison")).onChanged {
                                reveal = min(1, max(0, $0.location.x / max(width, 1)))
                            })
                            .accessibilityHidden(true)
                    }
                    .coordinateSpace(name: "visualComparison")
                    .clipped()
                }
            }
            .aspectRatio(mode == .reveal ? 390.0 / 844.0 : 788.0 / 844.0, contentMode: .fit)
            .background(Palette.surfaceMuted)
            .clipShape(RoundedRectangle(cornerRadius: Radii.md))
        } else {
            Text(VisualComparisonError.invalidImage.localizedDescription).foregroundStyle(Palette.textSecondary)
        }
    }

    private func image(_ value: UIImage, label: String) -> some View {
        Image(uiImage: value).resizable().aspectRatio(390.0 / 844.0, contentMode: .fit)
            .accessibilityLabel(label)
    }
}

private struct CaptureStamp: View {
    var title: String
    var capture: VisualCapture
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(title) · \(capture.commit)").font(.subheadline.weight(.semibold))
            Text(capture.deploymentTitle).font(.caption).foregroundStyle(Palette.textSecondary)
            Text("\(capture.route) · \(capture.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(Palette.textTertiary)
        }
    }
}

private struct ComparisonReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pair: ComparisonPair
    @State private var mode: ComparisonPresentation = .reveal
    @State private var reveal = 0.5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.md) {
                    Picker("Comparison view", selection: $mode) {
                        ForEach(ComparisonPresentation.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                    ComparisonCanvas(baseline: pair.baseline, candidate: pair.candidate, mode: mode, reveal: $reveal)
                    if mode == .reveal { Slider(value: $reveal) { Text("Reveal baseline") } }
                    CaptureStamp(title: "Baseline", capture: pair.baseline)
                    CaptureStamp(title: "Candidate", capture: pair.candidate)
                }.frame(maxWidth: 760).padding()
            }
            .taktCanvas().navigationTitle("Visual comparison").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarPinnedTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
