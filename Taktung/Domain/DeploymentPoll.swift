import Foundation

struct PollTick: Sendable {
    var attempt: Int
    var state: DeploymentState
    var atMs: TimeInterval
}

struct DeploymentPollResult: Sendable {
    var finalState: DeploymentState
    var attempts: Int
    var timedOut: Bool
    var ticks: [PollTick]
    /// True only when Vercel reported READY.
    var isReady: Bool
    var isFailed: Bool
    var isBlocked: Bool
    var summary: String
}

func isTerminalDeploymentState(_ state: DeploymentState) -> Bool {
    isSuccessState(state) || isFailedState(state) || state == .deleted || state == .unknown
}

/// Poll deployment until terminal or max attempts.
/// Never treats in-flight as success.
func pollDeploymentUntilTerminal(
    getState: () async throws -> DeploymentState,
    sleep: (UInt64) async -> Void = { try? await Task.sleep(nanoseconds: $0) },
    intervalNs: UInt64 = AppConfig.pollIntervalNanoseconds,
    maxAttempts: Int = AppConfig.pollMaxAttempts,
    now: () -> TimeInterval = { Date().timeIntervalSince1970 * 1000 }
) async throws -> DeploymentPollResult {
    var ticks: [PollTick] = []
    var last: DeploymentState = .unknown

    for attempt in 1...maxAttempts {
        last = try await getState()
        ticks.append(PollTick(attempt: attempt, state: last, atMs: now()))
        if isTerminalDeploymentState(last) && !isInFlightState(last) {
            if last == .unknown && attempt < 3 {
                await sleep(intervalNs)
                continue
            }
            if last != .unknown || attempt >= maxAttempts {
                return finalizePoll(last, attempts: attempt, timedOut: false, ticks: ticks)
            }
        }
        if attempt < maxAttempts {
            await sleep(intervalNs)
        }
    }
    return finalizePoll(last, attempts: maxAttempts, timedOut: true, ticks: ticks)
}

private func finalizePoll(
    _ finalState: DeploymentState,
    attempts: Int,
    timedOut: Bool,
    ticks: [PollTick]
) -> DeploymentPollResult {
    let ready = isSuccessState(finalState)
    let blocked = finalState == .blocked || finalState == .deleted || finalState == .unknown
    let failed = isFailedState(finalState) || blocked
    let summary: String
    if timedOut {
        summary =
            "Still \(finalState.rawValue) after \(attempts) poll(s) — not claiming success. Refresh later."
    } else if ready {
        summary = "Deployment READY after \(attempts) poll(s) (Vercel confirmed)."
    } else if blocked {
        summary =
            "Deployment was blocked in terminal state \(finalState.rawValue) after \(attempts) poll(s)."
    } else if failed {
        summary = "Deployment ended \(finalState.rawValue) after \(attempts) poll(s)."
    } else {
        summary = "Deployment reached \(finalState.rawValue) after \(attempts) poll(s)."
    }
    return DeploymentPollResult(
        finalState: finalState,
        attempts: attempts,
        timedOut: timedOut,
        ticks: ticks,
        isReady: ready,
        isFailed: failed,
        isBlocked: blocked,
        summary: summary
    )
}
