import Foundation

enum DemoIDs {
    static let team = "team_demo"
    static let portfolio = "prj_demo_portfolio"
    static let store = "prj_demo_store"
    static let docs = "prj_demo_docs"
    static let blog = "prj_demo_blog"
}

let demoUser = VercelUser(id: "uid_demo", name: "Example", username: "example", email: nil)
let demoTeam = VercelTeam(id: DemoIDs.team, name: "Example team", slug: "example-team")

private struct SiteSpec: Sendable {
    var id: ProjectID
    var name: String
    var domain: String
    var repo: String
    var framework: String
    var commit: String
    var sha: String
}

private let sites: [SiteSpec] = [
    SiteSpec(
        id: DemoIDs.portfolio,
        name: "example-portfolio",
        domain: "example-portfolio.app",
        repo: "portfolio",
        framework: "nextjs",
        commit: "Update landing page layout",
        sha: "7f3a21c9e0ab4d1"
    ),
    SiteSpec(
        id: DemoIDs.store,
        name: "example-store",
        domain: "example-store.app",
        repo: "store",
        framework: "nextjs",
        commit: "Fix checkout button spacing",
        sha: "b4c91e20aa17d8f"
    ),
    SiteSpec(
        id: DemoIDs.docs,
        name: "example-docs",
        domain: "example-docs.app",
        repo: "docs",
        framework: "nextjs",
        commit: "Update getting started guide",
        sha: "c8d02f41bb90e3a"
    ),
    SiteSpec(
        id: DemoIDs.blog,
        name: "example-blog",
        domain: "example-blog.app",
        repo: "blog",
        framework: "nextjs",
        commit: "Add post about launch week",
        sha: "d1e38a56cc04b72"
    ),
]

private let portfolioCommits: [(message: String, sha: String, minutesAgo: Double)] = [
    ("Update landing page layout", "7f3a21c9e0ab4d1", 12),
    ("Tighten mobile hero spacing", "aecd30ab19c4e02", 17),
    ("Fix production image cache", "0b4ed78c2aa91f3", 31),
    ("Refresh project README", "cff17d71e8b03a4", 38),
    ("Improve navigation labels", "db3060d44c1e5b6", 62),
    ("Align section headings", "18f3391aa07c8d2", 68),
    ("Restore production redirect", "ad584e3221b9f70", 75),
    ("Reduce unused CSS", "2960bda88e4c1a3", 130),
    ("Fix footer link order", "a085fa011d7e9c4", 185),
    ("Add missing alt text", "95cc1bc77a2d8e1", 190),
    ("Ship dark-mode tokens", "044666f5b3c0a29", 310),
    ("Polish contact form", "1f970133e6d4b80", 430),
    ("Bump dependencies", "0459e571aa8c2f6", 540),
    ("Adjust card shadows", "5571c7e90bb3d14", 660),
    ("Clean up unused routes", "d032d73cc91e5a8", 720),
    ("Refresh Open Graph images", "b20c45811f7a6d0", 740),
]

private let previewFailures: [(message: String, sha: String, minutesAgo: Double)] = [
    ("Fix preview build cache", "1cff9c4aa02e7b1", 545),
    ("Retry broken preview compile", "88a1b2c3d4e5f60", 800),
    ("Restore missing preview env keys", "f1e2d3c4b5a6978", 900),
]

private func deploy(
    id: String,
    name: String,
    state: DeploymentState,
    target: DeploymentTarget?,
    createdAt: TimeInterval,
    message: String,
    sha: String,
    ref: String = "main"
) -> VercelDeploymentSummary {
    VercelDeploymentSummary(
        id: id,
        url: nil,
        name: name,
        state: state,
        target: target,
        createdAt: createdAt,
        readyAt: state == .ready ? createdAt + 32_000 : nil,
        buildingAt: createdAt - 12_000,
        source: "git",
        creatorUsername: "example",
        isRollbackCandidate: state == .ready && target == .production,
        region: "iad1",
        meta: GitMeta(
            githubCommitRef: ref,
            githubCommitSha: sha,
            githubCommitMessage: message,
            githubCommitAuthorName: nil,
            githubCommitAuthorLogin: "example"
        ),
        inspectorUrl: nil,
        aliases: nil,
        buildDurationMs: state == .ready ? 32_000 : nil,
        lambdaOutputs: nil
    )
}

func buildDemoConnection() -> VercelConnection {
    VercelConnection(
        status: .connected,
        user: demoUser,
        teams: [demoTeam],
        selectedTeamId: DemoIDs.team,
        errorMessage: nil
    )
}

func buildDemoDeployments(projectId: ProjectID, now: Date = Date()) -> [VercelDeploymentSummary] {
    guard let site = sites.first(where: { $0.id == projectId }) else { return [] }
    let nowMs = now.timeIntervalSince1970 * 1000
    if projectId != DemoIDs.portfolio {
        return [
            deploy(
                id: "dpl_demo_\(site.repo)_prod",
                name: site.name,
                state: .ready,
                target: .production,
                createdAt: nowMs - 36 * 60_000,
                message: site.commit,
                sha: site.sha
            )
        ]
    }
    let ready = portfolioCommits.enumerated().map { i, row in
        deploy(
            id: "dpl_demo_portfolio_\(i)",
            name: site.name,
            state: .ready,
            target: .production,
            createdAt: nowMs - row.minutesAgo * 60_000,
            message: row.message,
            sha: row.sha
        )
    }
    let failed = previewFailures.enumerated().map { i, row in
        deploy(
            id: "dpl_demo_portfolio_fail_\(i)",
            name: site.name,
            state: .error,
            target: .preview,
            createdAt: nowMs - row.minutesAgo * 60_000,
            message: row.message,
            sha: row.sha,
            ref: "preview"
        )
    }
    return (ready + failed).sorted { $0.createdAt > $1.createdAt }
}

func buildDemoProjects(now: Date = Date()) -> [VercelProject] {
    sites.map { site in
        let deploys = buildDemoDeployments(projectId: site.id, now: now)
        let production = deploys.first { $0.target == .production && $0.state == .ready }
        return VercelProject(
            id: site.id,
            name: site.name,
            framework: site.framework,
            nodeVersion: "22.x",
            primaryDomain: site.domain,
            productionDeployment: production,
            latestDeployment: deploys.first ?? production,
            lastSuccessfulDeployment: production,
            latestFailedDeployment: nil,
            needsAttention: false,
            attentionReason: .none,
            teamId: DemoIDs.team,
            link: ProjectLink(type: "github", repo: site.repo, org: "example")
        )
    }
}

func findDemoDeployment(_ id: DeploymentID, now: Date = Date()) -> VercelDeploymentSummary? {
    for site in sites {
        if let match = buildDemoDeployments(projectId: site.id, now: now).first(where: { $0.id == id }) {
            return match
        }
    }
    return nil
}

func buildDemoActivity(now: Date = Date()) -> [ActivityItem] {
    func iso(_ minutesAgo: Double) -> Date {
        now.addingTimeInterval(-minutesAgo * 60)
    }
    return [
        ActivityItem(
            id: "act_demo_loaded",
            kind: .refreshProjects,
            title: "Loaded projects",
            detail: "4 project(s) (list without N+1 deploy fan-out)",
            outcome: .success,
            createdAt: iso(2)
        ),
        ActivityItem(
            id: "act_demo_connect",
            kind: .connect,
            title: "Connected to Vercel",
            detail: "Restored personal access token session",
            outcome: .success,
            createdAt: iso(2)
        ),
        ActivityItem(
            id: "act_demo_deploys",
            kind: .loadDeployments,
            title: "Loaded deployments",
            detail: "19 deployment(s)",
            outcome: .success,
            createdAt: iso(3)
        ),
        ActivityItem(
            id: "act_demo_refresh",
            kind: .refreshProjects,
            title: "refresh projects",
            detail: "refresh_projects:success",
            outcome: .success,
            createdAt: iso(8)
        ),
        ActivityItem(
            id: "act_demo_connect_earlier",
            kind: .connect,
            title: "connect",
            detail: "connect:success",
            outcome: .success,
            createdAt: iso(8)
        ),
    ]
}

func demoHasIdentifyingCopy(_ text: String) -> Bool {
    let pattern = #"([a-z0-9._%+-]+)@([a-z0-9.-]+\.[a-z]{2,})"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
        return false
    }
    let range = NSRange(text.startIndex..., in: text)
    let matches = regex.matches(in: text, range: range)
    for match in matches {
        if match.numberOfRanges >= 3, let hostRange = Range(match.range(at: 2), in: text) {
            let host = text[hostRange].lowercased()
            if host.hasPrefix("example.") { continue }
            return true
        }
        return true
    }
    return false
}
