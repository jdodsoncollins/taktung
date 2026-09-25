import Testing
@testable import Taktung

struct DeploymentPollTests {
    @Test func claimsReadyOnlyWhenReady() async throws {
        var states: [DeploymentState] = [.building, .building, .ready]
        let result = try await pollDeploymentUntilTerminal(
            getState: {
                let next = states.isEmpty ? DeploymentState.ready : states.removeFirst()
                return next
            },
            sleep: { _ in },
            intervalNs: 0,
            maxAttempts: 5
        )
        #expect(result.isReady)
        #expect(result.finalState == .ready)
        #expect(!result.timedOut)
        #expect(result.attempts == 3)
    }

    @Test func errorIsNotSuccess() async throws {
        let result = try await pollDeploymentUntilTerminal(
            getState: { .error },
            sleep: { _ in },
            intervalNs: 0,
            maxAttempts: 3
        )
        #expect(!result.isReady)
        #expect(result.isFailed)
        #expect(result.finalState == .error)
    }

    @Test func timeoutDoesNotClaimReady() async throws {
        let result = try await pollDeploymentUntilTerminal(
            getState: { .building },
            sleep: { _ in },
            intervalNs: 0,
            maxAttempts: 3
        )
        #expect(result.timedOut)
        #expect(!result.isReady)
        #expect(result.finalState == .building)
    }
}
