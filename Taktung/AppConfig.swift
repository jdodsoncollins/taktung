import Foundation

enum AppConfig {
    static let displayName = "Taktung"
    static let bundleID = "com.jcollins.takt"
    static let urlScheme = "takt"
    static let oauthRedirectURI = URL(string: "takt://oauth/callback")!
    static let privacyPolicyURL = URL(string: "https://www.jeremycollins.net/takt-privacy-policy")!
    static let otherAppStoreURL = URL(string: "https://apps.apple.com/us/app/codable/id1324741659")!
    static let otherAppName = "Codable"
    static let otherAppBlurb =
        "Inspect the live page from your phone. DOM, styles, console, and network where it already runs."
    static let vercelAPIBase = URL(string: "https://api.vercel.com")!
    static let pollIntervalNanoseconds: UInt64 = 3_000_000_000
    static let pollMaxAttempts = 40
}
