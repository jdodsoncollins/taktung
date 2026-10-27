# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Developers checking their Vercel sites from an iPhone or iPad. The main workflows are understanding what is live, reviewing a deployment change and investigating a failed build. The redesigned first screen leads with production state and a directly reachable comparison task, following the user’s selected differentiators and task-focused developer-tool references.

## Product Purpose

Taktung is a native Vercel operations app. It shows the selected site’s production state, explains loaded build evidence and prepares explicitly confirmed deployment actions.

## Positioning

Real visual comparison and a persistent local journal of checks, notes and saved baselines are the capabilities the user selected to distinguish this app from an MCP or plugin workflow.

## Operating Context

Short inspections on a phone, longer comparisons on an expanded Duo or iPad, with the same selection and evidence surviving folding and navigation.

## Capabilities and Constraints

- Native SwiftUI, iOS 27 minimum, Xcode 27.1 SDK. Bundle identity and App Store identity remain unchanged.
- Selected Vercel project is the site scope. No cross-project deployment fan-out from Home or site selection.
- Product data comes from the live REST API. Screenshot/demo fixtures remain isolated.
- The released 1.6 build adds a Home tool directory independent of the LLM: Vercel activity, domain ownership, actual deployment checks, cron schedules and flag names. Build logs expose a searchable newest-500 window; runtime logs are a bounded stream for one deployment. Deployment search combines text, target and state. See [inspection scope and limits](docs/project-inspection.md).
- Version 1.7 adds selected-project Vercel Web Analytics: visitors, page views, daily traffic, pages/referrers/countries/devices and completed UTC reporting windows. Availability depends on the project’s instrumentation, role and Vercel plan. No visit records enter history or AI prompts.
- Other Apps includes the owner’s published Codable, TabForge and Paper & Grain detail pages and App Store links.
- The 1.8 candidate adds an optional Tip Jar in Settings, following TabForge’s scene-aware StoreKit flow. Repeatable tips never unlock features or change Vercel access; prices come from Apple’s localized storefront.
- Environment values never appear in UI, journal or briefs.
- Mutations retain allow-listed plans, confirmation policy and hard confirmation. READY requires polling; promotion/rollback verify production target.
- Actual WebKit captures have commit, route and time provenance; local baselines and journal are isolated by account/team.
- Heuristic Diagnose always works; model-only Search chrome is hidden when unavailable except in demo.
- Light, Dark and System appearance are user-selectable and persistent.
- Small, medium and large Home Screen widgets default to All projects in the current workspace; native Edit Widget settings can pin each widget to one project independently of app site selection. Widgets follow system appearance and show a bounded recent sample, latest deployment, and freshness. Large adds recent deployment activity from the same sample. The later listing must feature genuine widget captures in Taktung's distinct inspection-sheet format.
- Siri and Shortcuts can read fresh deployment status for all projects or one project, open project evidence, run a site-health explanation in the app, or open Deploys and Field Log. These actions do not mutate deployments; project evidence requires authentication. Site health explains loaded signals rather than testing website uptime.
- Apple Intelligence summaries use compact evidence, fresh sessions and actual
  token budgeting. Heuristics remain immediately useful while generation runs.
  Identical evidence can reuse an accepted summary briefly; repeated in-flight
  checks coalesce, and obsolete generation is cancelled when scope changes.

## Brand Commitments

Keep Taktung’s name, bundle identity and App Store identity. The selected C abstract metronome preserves the name's history and fits the adaptive neutral/teal interface. The user’s Vercel screenshots establish a restrained developer-tool hierarchy, familiar controls and task-focused information, while the app’s composition and accent remain its own. Do not copy Vercel’s UI or colors exactly.

App icons must use the standard layered `.icon` format with intentional light and dark appearances. The user selected concept C, an abstract metronome: a neutral frame with a teal pendulum and counterweight. This preserves the name's visual history while fitting the new interface. It was initially implemented in 1.5.0 (40). Build 41 corrects the body/base alignment to a shared canvas center, preserving the angled pendulum, counterweight and palette; split inspection frame and overlapping evidence pages remain unchosen studies. Settings uses matching verified Apple icon renders.

Marketing communicates the inspection job through number-free inspection sheets and genuine app captures, distinct from Codable's promotional style. The user requested a 1.6 refresh with Apple device frames, larger bold type and primary-color captions while preserving the current wording. `artifacts/app-store-1.6.0-43/` retains the seven messages, adds Project tools, and includes genuine small/medium/large widgets. Duo inner imagery shows the expanded two-column workspace in landscape; outer remains closed portrait. Attribution, source hashes and review evidence are retained with the editable studio.

Editable 1.5.0 store copy now includes small/medium/large widgets, project filtering and recent activity. Canonical text is in `metadata/`. The user approved the App Store descriptor “Taktung: Deployment Status,” subtitle “Vercel logs, compare & widgets,” revised copy/keywords and Developer Tools primary category on 2026-10-12. These are applied to editable 1.5.0, with the base Taktung name and bundle identity unchanged. Lead proposed copy with deployment status, real comparison and local evidence; do not promise continuous uptime monitoring or automated recovery.

## Evidence on Hand

Two user-supplied Vercel mobile screenshots and a Codable spacing reference. Reviewed native captures and submitted listing sources are in `artifacts/app-store-1.5.0-42/public/screenshots`; live regression evidence remains separate under `.impeccable/review/`. The user authorized all completed features in 1.5.0 (42); the October 12 record confirms submission with automatic release after approval. The October 17 requests separately authorized 1.6.0 (43) for internal TestFlight and then App Store release. It is now WAITING_FOR_REVIEW with automatic release after approval; all 28 refreshed images are COMPLETE with verified checksums. The previous 1.5 set had 25 verified exports; 1.6 retains its widget, Settings, comparison and Field Log evidence in the refreshed format. Build 41's earlier withdrawal and its centered selected C evidence remain historical. [Icon direction](docs/icon-direction.md) and [release evidence](docs/release-1.5.0-42.md) record the implementation and verification limits. No invented usage metrics, server-wide audit claims or automated regression scores.

## Product Principles

The [October 17 Vercat research](docs/vercat-research-2026-10-17.md) maps broader tooling to verified Vercel APIs and official CLI contracts. Its core inspection candidates are implemented in the 1.6 TestFlight build: searchable build logs, runtime samples, Vercel activity, domain ownership, checks and a discoverable tool directory with tested read-only cron/flag adapters. Metrics, spending, invoices, storage discovery and alerts retain separate capability/contract limits. The inspection/comparison/Field Log positioning remains the same.

1. Lead with the user’s next inspection task and its evidence.
2. Keep platform controls and familiar navigation.
3. Show actual state and provenance without decorative technical theater.
4. Preserve local evidence and account/team privacy boundaries.
5. Keep appearance and capability consistent across compact and expanded screens.
