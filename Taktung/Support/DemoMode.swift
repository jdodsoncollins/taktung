import Foundation

/// Screenshot-only fixture path. Off unless launch arg / env / Settings toggle
/// is set. Live Vercel is never mixed with these fixtures.
enum DemoMode {
    /// Test hook. When set, overrides process/env/defaults.
    nonisolated(unsafe) static var override: Bool?

    private static let defaultsKey = "TAKT_DEMO_MODE"

    static var isEnabled: Bool {
        if let override { return override }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-TAKT_DEMO_MODE") { return true }
        if let value = ProcessInfo.processInfo.environment["TAKT_DEMO_MODE"] {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes"].contains(normalized) { return true }
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func setUserToggle(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: defaultsKey)
    }

    static func demoModeEnabled(_ value: String?) -> Bool {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes"
    }
}
