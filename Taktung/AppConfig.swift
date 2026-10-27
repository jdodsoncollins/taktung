import Foundation

enum AppConfig {
    static let displayName = "Taktung"
    static let bundleID = "com.jcollins.takt"
    static let widgetBundleID = "com.jcollins.takt.widgets"
    static let widgetKind = "TaktungDeploymentStatus"
    static let accessTokenKey = "vercel.access-token"
    static let widgetSnapshotKey = "widget.selected-site"
    static let demoWidgetSnapshotKey = "widget.demo-site"
    static let urlScheme = "takt"
    static let oauthRedirectURI = URL(string: "takt://oauth/callback")!
    static let privacyPolicyURL = URL(string: "https://www.jeremycollins.net/taktung/privacy")!
    static let otherApps: [CompanionApp] = [
        CompanionApp(id: "codable", name: "Codable", icon: "CodableMark", detail: "Inspect pages, edit styles and run JavaScript right in Safari.", storeID: "1324741659"),
        CompanionApp(id: "tabforge", name: "TabForge", icon: "TabForgeMark", detail: "A programming keyboard with indentation, cursor controls and saved snippets.", storeID: "6824056795"),
        CompanionApp(id: "paper-and-grain", name: "Paper & Grain", icon: "PaperGrainMark", detail: "Fold, cut and draw paper. Learn origami or explore Free Fold on iPhone and iPad.", storeID: "6821361967")
    ]
    static let vercelAPIBase = URL(string: "https://api.vercel.com")!
    static let pollIntervalNanoseconds: UInt64 = 3_000_000_000
    static let pollMaxAttempts = 40
}

struct CompanionApp: Identifiable {
    let id: String
    let name: String
    let icon: String
    let detail: String
    let storeID: String
    var detailURL: URL { URL(string: "https://www.jeremycollins.net/\(id)")! }
    var storeURL: URL { URL(string: "https://apps.apple.com/app/id\(storeID)")! }
}
