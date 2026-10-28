# Taktung

**Taktung** (German: *putting work on a beat*) is a local-first **Vercel
operations assistant**. This repository is the **native SwiftUI** port of
the Expo Takt app. The App Store name is Taktung because Takt is already
used by other apps. Bundle ID and URL scheme match Takt:
`com.jcollins.takt` / `takt://`.

> Show me what changed, explain what broke, and prepare the safest next action.

This is **not** a full Vercel dashboard clone. It is a mobile control plane
for incident, deployment, and configuration intelligence — with hard
confirmation for mutators and honest success/failure in Activity.

Source is [MIT](LICENSE).

Version **1.8.1 (47) is Waiting for App Store Review** and available in internal TestFlight, with automatic App Store release after approval. It fixes Web Analytics loading and explains Vercel errors instead of reporting a connection problem; see the [1.8.1 release record](docs/release-1.8.1-47.md). App Store Connect shows 1.8.0 (46) live. That release added optional Apple tips in Settings and kept Codable, TabForge and Paper & Grain in Other Apps. It also shipped the Web Analytics work, all widgets and shortcuts, project inspection, visual comparison, Field Log and centered icon C. The listing retains 31 number-free images and two iPhone/iPad App Preview videos. See the [1.8.0 release record](docs/release-1.8.0-46.md), [Tip Jar architecture](docs/tip-jar.md), [analytics architecture](docs/web-analytics.md) and [listing imagery](docs/app-store-imagery.md) for the verified distribution state. The earlier 1.7 review was withdrawn; 1.7.1 remained an unsubmitted draft. App Store Connect confirmed [1.6.0 (43)](docs/release-1.6.0-43.md) live on October 20.

---

## Features

| Area | What you get |
|------|----------------|
| **Home / projects** | Selected **site** briefing, production state, needs-attention, and “Since you last looked”: new deployments, failures and production changes since the site was last on screen. Header switches sites on every tab |
| **Deployments** | Search commit/branch/SHA/URL; combine Production/Preview with status filters. Redeploy / promote / rollback stay hard-confirm actions |
| **Project tools** | Web Analytics, remote Vercel activity, domain ownership, actual checks, cron schedules and flag names; available without an LLM |
| **Web Analytics** | Visitors, page views, daily traffic and pages/referrers/countries/devices for the selected site; completed UTC reporting windows and honest access/plan states |
| **Logs** | Search, timestamps, errors-only filter and redacted copy/share for up to 500 build lines; bounded runtime stream for one deployment |
| **Visual comparison** | Fresh WebKit page captures, reveal slider, side-by-side review, and saved route baselines with commit/time provenance |
| **History** | Persistent device history, site filters, notes, entry detail, and text export; isolated by account and team. Search in plain language (“failed checks this week”, “notes about checkout”) and summarize the last 7 days, with counts on every device |
| **Home Screen widgets** | Small, medium and large deployment status/counts with recent activity, native Edit Widget project filter, All projects by default, system appearance |
| **Siri / Shortcuts** | Fresh deployment status with spoken/composable output, optional project filters, project inspection, site-health explanation and direct navigation |
| **Incident summary** | Deterministic diagnosis from logs, env presence, last success, with the key redacted log lines; an optional on-device sentence explains them |
| **Spotlight** | Opt-in recent deployments and Field Log notes in system search, removed on switch off, team change or disconnect |
| **Env drift** | Names and targets only — **never secret values** |
| **READY poll** | After mutators, Activity records READY only when Vercel confirms |
| **Tip Jar** | Optional repeatable Apple tips in Settings; no feature unlocks, backend or saved purchase history |
| **Auth** | Personal access token (Keychain). OAuth PKCE support is planned |
| **Demo** | Screenshot fixture path. Off unless `TAKT_DEMO_MODE` is set. Never mixed with live Vercel |
| **Search** | Plain-language deployment search for the selected site (“successful deploys this week”, “last failed preview on main”) as live, read-only Vercel requests; site lookup and the env check. Available on every device. Where Apple Intelligence can run, it reads phrasing the built-in rules don't recognise, behind an on/off switch on the Search page |
| **UI** | SwiftUI, iOS 27.1 SDK, adaptive split workspaces, Liquid Glass chrome, opaque adaptive neutral content, with persistent System / Light / Dark appearance |

### Safety rules

- Env variable **values** never enter the UI, Activity, or ops brief
- No arbitrary shell or free-form API from model output
- Typed, allow-listed actions only
- Hard confirmation for redeploy, promote, rollback
- Deployment success is only claimed when Vercel reports **READY**; promote and rollback also verify the production target
- Site changes invalidate pending confirmations and stale deployment responses
- Build logs redact credential assignments before display or analysis
- The on-device model sees build-log or Field Log text only as bounded, redacted excerpts; never runtime logs or env values

### Control plane

```text
Vercel adapter
  → normalized resources
  → typed action plans
  → local analysis
  → review / hard confirm
  → confirmed execution
  → persistent local activity journal
```

### Visual comparison and Field Log (1.3.0)

Deployment detail → Compare captures a READY candidate and an earlier READY deployment at the same page path. Save a candidate as a baseline to compare later deploys against an accepted image. Captures use a fixed 390 × 844 light viewport and anonymous WebKit sessions; protected pages report that they cannot be captured.

Activity retains the latest 1,000 records per account/team on this device, including notes and comparison events. It supports search, site filters, full entry details, and explicit text export. Saved images and history survive app restarts; disconnect erases the account's local evidence. Version 1.3.0 (36) adds the Field Log composition: daily sections, a restrained neutral rail, native filters and search, and a new-entry button that preserves the reader's position. Note retries reuse the original record ID so recovery cannot duplicate a note.

See [visual comparison and history](docs/visual-comparison-and-history.md) for storage, privacy, limitations, and validation, and the [quality assessment](docs/quality-review.md) for the bugs fixed and remaining checks.

---

## App structure

```text
taktung/
├── Taktung.xcodeproj
├── Taktung/
│   ├── TaktungApp.swift
│   ├── Domain/           # Pure logic (no SwiftUI / network)
│   ├── Services/         # Vercel REST, Keychain, demo client
│   ├── Shell/            # AppSession orchestration
│   ├── Features/         # Screens / sheets
│   ├── DesignSystem/     # Adaptive semantic tokens
│   └── Support/          # Demo fixtures, accessibility IDs
├── TaktungWidgets/      # WidgetKit/AppIntent extension; bounded read-only refresh
├── TaktungTests/
└── docs/
```

---

## Requirements

- **Xcode 27.1** (iOS 27.1 SDK)
- **iOS 27.0+**
- Apple Developer team for device/store builds (simulator works unsigned
  with Automatic signing)

## Build and run

```bash
open Taktung.xcodeproj
```

Or from the command line:

```bash
xcodebuild -scheme Taktung -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' build
```

### Demo mode (screenshots)

Off in store builds. Turn it on with the **Taktung Demo** scheme, a launch
argument, or `TAKT_DEMO_MODE` in Info.plist. Fixtures never mix with a live token.

```bash
xcrun simctl launch booted com.jcollins.takt -TAKT_DEMO_MODE
```

The **Taktung Demo** scheme sets this for you. Demo website previews render bundled HTML in WebKit without contacting a live site. Demo briefs stay deterministic even when an on-device model is available.

### Adaptive workspaces and store imagery

Home and deployment detail share `AdaptiveWorkspace`: one scrolling column at compact width, two independently scrolling panes at regular width, and iOS 27.1 `ArrangementView` split layout around active division regions. Navigation and selection remain outside the layout branches.

See [Duo readiness](docs/iphone-duo-readiness.md) for the runtime test matrix and [App Store imagery](docs/app-store-imagery.md) for the current editable studio, source captures and reviewed 31-image package. The [1.5.0 submission record](docs/release-1.5.0-42.md) preserves the earlier listing and review evidence. [1.6.0 (43)](docs/release-1.6.0-43.md) is live; [1.7.0 (44)](docs/release-1.7.0-44.md) adds Analytics.

### Appearance and on-device summaries

Settings offers persistent System, Light and Dark appearance. System changes also update an open Settings sheet. Home leads with production state and a direct comparison task; deployment mutations live in a native menu and retain hard confirmation. Settings uses the app icon’s matching light/dark appearance, and Other Apps uses bundled official artwork with full text wrapping.

Apple Intelligence availability refreshes on foreground activation and before a check. The heuristic brief appears immediately. Optional generation rewrites only that snapshot body, capped at 2,048 UTF-8 bytes and measured with the real model tokenizer. Each request uses a fresh session, greedy sampling and a 192-token response ceiling with context headroom. No log transcript, journal, environment values or model actions enter that request. Unavailable models and rejected responses retain the heuristic result. Identical scoped evidence reuses an accepted brief for up to five minutes; duplicate in-flight checks coalesce and site changes cancel obsolete work. See [Apple Intelligence lifecycle](docs/apple-intelligence.md).

Search turns a request into `GET /v7/deployments` filters for the selected site: state, Production/Preview, branch, commit SHA, time window and count. A deterministic vocabulary handles common phrasing instantly and without a model. Only words it cannot place go to the on-device model through guided generation; model values that are not literally in the request (branch, commit text, site) are discarded, and rule-decided filters always win. Each live result is checked again on the device. When no commit contains every typed word, related words (word forms, developer synonyms and on-device word-embedding neighbours) get one more pass, and the results say so. Results show their filters as removable chips, and the field's clear button or New search returns to suggestions and this launch's recent searches. See [Search](docs/apple-intelligence.md#search).

### Siri and Shortcuts

Settings → Siri & Shortcuts opens the system Shortcuts app. Ask “Check deploy status in Taktung,” or choose a project in a saved shortcut. Status returns the newest deployment and counts from the most recent 20 deploys. Inspect Project opens production evidence; Check Site Health refreshes the chosen site and explains its loaded signals. Empty Project means All projects for status and the current site for inspection/health. These actions are read-only and project evidence requires authentication. See [phrases, routing and verification](docs/siri-and-shortcuts.md).

### Personal access token

Create a token at [vercel.com/account/tokens](https://vercel.com/account/tokens).
Paste it in Settings. It is stored in the Keychain on this device only.

For UI tests you may pass `TAKT_UI_TOKEN` as a process environment variable.
Do not commit tokens.

### Tests

```bash
xcodebuild -scheme Taktung -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test
```

### Store releases

Native store builds use the `Taktung` scheme, Xcode 27.1, and `asc` archive/export/upload. The production Info.plist keeps demo mode off. Distribution signing uses the existing Apple Distribution identity in the normal login Keychain; `.asc/ExportOptions-1.7.0-44.plist` contains only public signing identifiers for the host and widget extension. Release configurations select matching App Store profiles explicitly, avoiding the older locked temporary keychain. See the [1.7 signing record](docs/release-1.7.0-44.md). Build and submission receipts live in `.asc/qa/`.

See the [1.5.0 (42) release record](docs/release-1.5.0-42.md) for the October 12 submission, signed host/extension validation, icon inspection and 25 verified listing images. The 1.6 regression passes 132 tests, including inspection API/privacy/scope, shortcut routing and brief lifecycle checks; [widget evidence](docs/widgets.md) records its earlier separate validation and physical-device limits. Widget support and approved discoverability copy are included in submitted 1.5.0, preserved in canonical `metadata/`. [Discovery audit](docs/app-store-discovery.md) records implementation and measurement access limits. App Store identity remains `com.jcollins.takt` / app `6805738660`.

---

## Sister apps

- [takt](https://github.com/jdodsoncollins/takt) — Expo / React Native original
- [MobileflowRN](https://github.com/jdodsoncollins/MobileflowRN) — Webflow ops (separate product)

Keep the codebases separate.

Implementation research: [Vercat feature/API map and typography observations](docs/vercat-research-2026-10-17.md). The implemented 1.6 subset and validation limits are recorded in [project inspection](docs/project-inspection.md). Metrics, spending, invoice history, storage enumeration and alerts remain separate contract/capability investigations.

### Web Analytics (1.7)

Project tools includes selected-project visitors, page views, daily traffic and page/referrer/country/device breakdowns through Vercel’s public Web Analytics API. Requests are bounded, read-only and guarded by the current connection scope. See [analytics implementation](docs/web-analytics.md) and [Other Apps catalog](docs/other-apps-catalog.md). Release evidence is tracked in [1.7.0 (44)](docs/release-1.7.0-44.md).

### Optional tips (1.8)

Settings → Tip Jar uses the latest TabForge scene-aware StoreKit pattern, with five localized repeatable consumables. Cancellation and pending approval never become success; verified transactions are handled by the app-scoped listener. The widget extension is unchanged. See [implementation and local testing](docs/tip-jar.md) and [release state](docs/release-1.8.0-46.md). Canonical [app](https://www.jeremycollins.net/taktung) and [privacy](https://www.jeremycollins.net/taktung/privacy) URLs are reflected in the listing and app.
