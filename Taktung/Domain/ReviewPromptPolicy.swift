import Foundation

/// Anonymous, device-local cadence. Counts successful use, never a star preference.
struct ReviewPromptPolicy: Codable {
    static let storageKey = "taktung.reviewPrompt.v1"
    var firstUse: Date
    private(set) var inspectionDays: [Date] = []
    private(set) var lastRequest: Date?

    mutating func recordInspection(at now: Date, calendar: Calendar = .current) {
        guard now >= firstUse else { return }
        let day = calendar.startOfDay(for: now)
        inspectionDays.removeAll { now.timeIntervalSince($0) > 90 * 86_400 }
        if !inspectionDays.contains(day) { inspectionDays.append(day) }
        inspectionDays = Array(inspectionDays.suffix(90))
    }

    func isEligible(at now: Date) -> Bool {
        guard now.timeIntervalSince(firstUse) >= 7 * 86_400,
              inspectionDays.filter({ now.timeIntervalSince($0) >= 0 && now.timeIntervalSince($0) <= 90 * 86_400 }).count >= 3 else { return false }
        return lastRequest.map { now.timeIntervalSince($0) >= 120 * 86_400 } ?? true
    }

    mutating func recordRequest(at now: Date) { lastRequest = now }
}

struct ReviewOpportunity: Identifiable {
    var id = UUID()
    var projectID: ProjectID
    var scope: EvidenceScope
    var mayPrompt: Bool
}
