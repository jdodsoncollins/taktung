import Foundation
import Testing
@testable import Taktung

@Suite(.serialized)
struct FeatureAvailabilityTests {
    @MainActor private func isolatedSession() -> AppSession {
        AppSession(evidenceStore: LocalEvidenceStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }
    @Test @MainActor func changingSiteInvalidatesTheOldConfirmation() async {
        let previousOverride = DemoMode.override
        DemoMode.override = true
        defer { DemoMode.override = previousOverride }
        let session = isolatedSession()
        await session.bootstrap()
        session.requestMutation(mode: .redeploy)
        let pending = session.pendingMutation!
        await session.selectProject(DemoIDs.docs)
        #expect(session.pendingMutation == nil)
        await session.confirmMutation(pending)
        #expect(session.lastError == "Confirmation did not match the planned mutation.")
        #expect(!session.recentActivity.contains { $0.title == "Redeploy" })
    }

    @Test @MainActor func rejectsADeploymentFromAnotherSite() async {
        let previousOverride = DemoMode.override
        DemoMode.override = true
        defer { DemoMode.override = previousOverride }
        let session = isolatedSession()
        await session.bootstrap()
        let foreign = buildDemoDeployments(projectId: DemoIDs.docs).first!
        session.selectedDeployment = foreign
        session.requestMutation(mode: .promote)
        #expect(session.pendingMutation == nil)
        #expect(session.lastError?.contains("does not belong to the selected site") == true)
    }

    @Test @MainActor func changingDeploymentClearsThePreviousDiagnosis() async {
        let previousOverride = DemoMode.override
        DemoMode.override = true
        defer { DemoMode.override = previousOverride }
        let session = isolatedSession()
        await session.bootstrap()
        let failed = session.deployments.first { isFailedState($0.state) }!
        let ready = session.deployments.first { isSuccessState($0.state) }!
        await session.selectDeployment(failed.id)
        await session.runIncidentSummary()
        #expect(session.incidentDeploymentId == failed.id)
        #expect(session.incident != nil)
        await session.selectDeployment(ready.id)
        #expect(session.incident == nil)
        #expect(session.incidentDeploymentId == nil)
    }

    @Test @MainActor func heuristicDiagnosisDoesNotRequireAppleIntelligence() {
        let session = isolatedSession()
        session.onDeviceAvailable = false
        #expect(!session.canDiagnose)
        session.projects = buildDemoProjects()
        session.selectedProjectId = DemoIDs.portfolio
        #expect(session.canDiagnose)
    }

    @Test @MainActor func searchModelControlsFollowModelOrDemoAvailability() {
        let session = isolatedSession()
        session.onDeviceAvailable = false
        #expect(session.showsSearchModelControls == DemoMode.isEnabled)
        session.onDeviceAvailable = true
        #expect(session.showsSearchModelControls)
    }

    @Test @MainActor func availabilityRefreshHandlesDownloadAndDisableWithoutRelaunch() {
        var available = false
        let session = AppSession(demoMode: false, modelAvailability: { available })
        session.refreshModelAvailability()
        #expect(!session.onDeviceAvailable)
        #expect(!session.showsSearchModelControls)
        available = true
        session.refreshModelAvailability()
        #expect(session.onDeviceAvailable)
        #expect(session.showsSearchModelControls)
        available = false
        session.refreshModelAvailability()
        #expect(!session.showsSearchModelControls)
    }

    @Test @MainActor func openingAnotherWindowKeepsTheCurrentSelection() async {
        let previousOverride = DemoMode.override
        DemoMode.override = true
        defer { DemoMode.override = previousOverride }
        let session = isolatedSession()
        await session.bootstrap()
        await session.selectProject(DemoIDs.docs)
        await session.bootstrap()
        #expect(session.selectedProjectId == DemoIDs.docs)
    }
}
