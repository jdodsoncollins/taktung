import Foundation

/// Screenshot fixtures. Off unless a launch argument, environment variable,
/// or Info.plist `TAKT_DEMO_MODE` is set. Never mixed with a live token.
enum DemoMode {
    /// Test hook. When set, overrides process, environment, and plist.
    nonisolated(unsafe) static var override: Bool?

    static var isEnabled: Bool {
        if let override { return override }
        if ProcessInfo.processInfo.arguments.contains("-TAKT_DEMO_MODE") { return true }
        if demoModeEnabled(ProcessInfo.processInfo.environment["TAKT_DEMO_MODE"]) { return true }
        let bundled = Bundle.main.object(forInfoDictionaryKey: "TAKT_DEMO_MODE")
        if let flag = bundled as? Bool { return flag }
        if let flag = bundled as? String { return demoModeEnabled(flag) }
        return false
    }

    static func demoModeEnabled(_ value: String?) -> Bool {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes"
    }
}
