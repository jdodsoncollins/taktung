# Taktung agent notes

Native SwiftUI port of Takt. Keep this repo separate from the Expo Takt
codebase and from MobileflowRN.

- Bundle ID is `com.jcollins.takt` (same as Takt).
- Target iOS 27. Do not set `UIDesignRequiresCompatibility`.
- Site scope = selected Vercel project (header title). Do not N+1
  `listDeployments` from the site picker or Home.
- Live Vercel REST API only for product data. Demo fixtures never mix
  with a live token session.
- Env variable **values** must never appear in UI, Activity, or briefs.
- Mutating actions: allow-list + ConfirmationPolicy + hard confirm.
  READY only after poll.
- Liquid Glass on navigation chrome only; content = opaque HIG surfaces.
- Heuristic Diagnose always works. Hide Search LLM chrome when
  `OnDevicePlanner.isAvailable` is false, except in demo mode (screenshots).
- Prefer unit tests for domain/analysis and API mapping.
- Identity (bundle ID, team, privacy URL) lives in `AppConfig`.
- Update `README.md` and `docs/` when revising architecture.

## Product and visual direction

- Read `PRODUCT.md` for product truth and `DESIGN.md` for the visual system.
  Production evidence, real comparison and the local Field Log define the job.
- Use adaptive neutrals, restrained teal, native controls and Dynamic Type.
  Vercel references establish familiar developer-tool hierarchy; do not copy
  their branding, UI or exact colors.
- Marketing uses flat inspection sheets without sequence numbers, compact captions and genuine
  app captures. Keep Taktung's listing format distinct from Codable.
- For the 1.6 App Store refresh, the user requested Apple device frames and
  larger, higher-contrast text. Preserve existing headline/caption wording;
  add copy only for new features. Use measured Apple bezels from the attributed
  screenshot studio, genuine native captures and their source aspect ratios.
  Duo inner artwork now shows the expanded landscape workspace; outer remains
  closed portrait. See docs/app-store-imagery.md for sources and verification.
- Keep Apple Intelligence briefs compact and token-aware, use fresh sessions,
  and publish the heuristic without waiting for generation. Availability must
  reflect the actual device/model state; do not imply physical performance
  verification from simulator measurements.

## Project inspection tools (1.6)

- Home's Project tools directory is available independently of Apple Intelligence. Its read-only activity, domain, checks, cron and flag requests use the selected project and connected team. Do not add empty metric/billing/storage/alert destinations without validated contracts.
- Vercel activity is remote evidence; Field Log is the local inspection journal. Allow-list event metadata and discard raw payload text, environment values, flag variants and SDK keys.
- Build logs request the newest 500 events in backward order, then display chronologically. Search/copy/share operate on redacted loaded evidence. Keep the 2 MB response bound and preserve honest permission/error/empty states.
- Runtime logs are one deployment stream, bounded to 500 records / 2 MB. Incrementally frame records, cancel on Stop/navigation/scope change, and never call a sample an hourly or site-wide error total. No raw runtime records enter persistent history or AI prompts.
- Account/team/project/reconnection revisions guard every inspection publication. Fresh domain ownership findings and runtime counts can inform briefs for five minutes, in memory only. Reject generated summaries that omit required sample/ownership qualifications.
- Domain verification is ownership evidence, not uptime/TLS/DNS verification. Cron configuration is not run history; schedules are UTC. Empty checks do not imply passing checks or runtime health.
- 1.6.0 (43) is deployed to internal TestFlight and was separately authorized
  for App Store release on October 17. App Store Connect confirmed it live on October 20
  (READY_FOR_SALE / READY_FOR_DISTRIBUTION). All 28 refreshed
  listing images are COMPLETE and match reviewed local checksums. See
  docs/project-inspection.md and docs/release-1.6.0-43.md for scope and receipts.

## Web Analytics (1.7)

- Public Web Analytics visits/count and visits/aggregate returned real data for
  jeremycollins.net's current `jeremy-collins-dot-net` project. This feature is
  implemented for 1.7 under Project tools. Keep it separate from Observability metrics.
- Validate effective date bounds returned by each endpoint; inclusive aggregate
  bucket alignment can differ from count bounds. Never turn missing data into
  zero or sum segmented visitor counts into a unique audience. See
  docs/web-analytics-feasibility.md for the researched contract and docs/web-analytics.md for implementation.
- Analytics holds bounded aggregates in view memory only. Scope/reconnection revisions reject late results. Seven/30-day windows use completed UTC days; permission, plan and transport failures never become zero traffic.
- The user removed sequence-number badges from every App Store image on October 20. Preserve app data/date numbers and the existing captions; new analytics imagery uses the same unnumbered, framed format.
- 1.7.0 (44) was submitted October 20 and later withdrawn. On October 21 the editable version was renumbered to 1.7.1 (45), which remained an unsubmitted draft with a matching VALID build, 31 inherited number-free screenshots and two COMPLETE app previews. That draft was later superseded by the separately authorized 1.8 release. See docs/release-1.7.1-45.md; build 44's submission record remains historical.
- Release signing now uses the current Apple Distribution certificate in the normal login keychain and matching 1.7 App Store profiles. Do not select the older temporary release-13 keychain. See docs/release-1.7.0-44.md for receipts.

## Optional Tip Jar (1.8)

- Follow the latest TabForge scene-aware StoreKit implementation. The native Settings Tip Jar offers five repeatable consumables; it never unlocks features or changes Vercel/widget/shortcut access. Use only Product.displayPrice, with unavailable products disabled.
- IDs are com.jcollins.takt.tip.kind/thoughtful/wonderful/incredible/extraordinary; US base prices are $0.99/$1.99/$2.99/$3.99/$4.99. Do not reuse or modify TabForge's product records.
- Only verified, owned, non-revoked catalog consumables are finished. Handle cancellation, pending, failure, duplicate delivery and unfinished transactions distinctly. Keep transaction identifiers bounded in process memory; no purchase history, backend, upload or Vercel-account linkage.
- The Taktung Tips scheme / TipJar.xctestplan isolate local StoreKit tests. Never ship .storekit or StoreKitTest resources in the app/widget; give a simulator exclusive purchase-test ownership.
- Marketing URL: https://www.jeremycollins.net/taktung. Privacy URL: https://www.jeremycollins.net/taktung/privacy. Keep AppConfig and canonical metadata aligned. See docs/tip-jar.md and docs/release-1.8.0-46.md for actual verification and release state.
- The user authorized submitting the completed 1.8 release on October 21. Preserve the 31 number-free screenshots and two COMPLETE iPhone/iPad App Previews; the withdrawn 1.7 review is historical.
- 1.8.0 (46) was accepted for review on October 21 at 16:25 UTC: submission 63756a2e-3e9f-4f5c-9103-24aa69215ae1 is WAITING_FOR_REVIEW, as are all five tip products. Build a6c6129f-23d8-48cb-896e-023a77e3b0ae is VALID / IN_BETA_TESTING. Release is automatic after approval; do not call it publicly live yet.
- Settings Done uses the standard confirmationAction toolbar placement; pinned placement exposed an iPad UIKit focus crash on Back. Preserve native value-based destinations and the stable sheet alert presenter. Final phone, iPad and Duo flows passed. See the release record for initial failure and repair receipts.
- The user approved and published the Tip Jar privacy correction through website PR #30, production commit 4c52535aa142bcbffc4cbb5874e5ba370655371b. The /taktung/privacy page is live; it must no longer claim the app is not monetized.

## Icon evolution

- The user has opened the icon direction for reconsideration. Preserve the
  name and bundle identity; the copper metronome is not binding for future
  artwork. See `docs/icon-direction.md` for considered directions.
- Replacements must be standard Xcode/Icon Composer `.icon` documents with
  independently editable foreground layers and intentional Default/light and
  Dark variants. One flattened PNG per appearance does not meet the new layer
  requirement. Preserve system tinted/mono support.
- Use the neutral/teal pairs in `DESIGN.md`, a consistent silhouette and shapes
  readable at small sizes. Let the system supply the icon mask and materials;
  do not bake rounded app tiles, gloss, lighting or shadows into source art.
- The user selected concept C, the abstract metronome. Its neutral frame,
  teal pendulum and counterweight are implemented as separate SVG layers in
  `Taktung/AppIcon.icon` for 1.5.0 (41). Split inspection frame and evidence
  pages remain unchosen studies; do not substitute them.
- The body and base must share x=512 on the 1024 px source canvas. Body
  mirror pairs sum to 1024 in every appearance; preserve clearance around
  the angled pendulum/counterweight. Record centering verification.
- Validate a replacement in Icon Composer and Xcode, inspect rendered variants,
  and regenerate `TaktungMark` from verified renders for Settings. Update origin
  records and listing captures containing the icon. Record the actual build
  and review state accurately.
- Settings artwork follows the resolved in-app appearance, including forced
  Light/Dark. Home Screen icon appearance remains system-owned.

## Home Screen widgets

- Use standard WidgetKit/AppIntentConfiguration, small, medium and large families. The native long-press Edit Widget project picker defaults to All projects. A widget filter is independent of the app's selected site; account/team scope still follows the connected workspace.
- Follow the system appearance, independent of forced in-app Light/Dark. Use SF text styles, semantic surfaces, restrained teal, and accessible state symbols.
- Counts describe the 20 most recent deploys in that widget's scope, not all-time totals. Latest means newest created deployment across targets, not the production alias. All projects uses one workspace GET, never per-project fan-out.
- Large adds the latest five deployment records from that same sample (three at accessibility text sizes). Name it Recent deploys; current status is not a historic status-transition log. Never render raw build-log output or environment values in widgets.
- Read credentials from the app's existing device-only Keychain group. Keep summaries/catalog/caches secret-free. The extension cannot mutate deployments or host context.
- Host-owned account/team revision invalidates pending widget responses; removed projects must not silently become All projects. Cache by revision and filter; clear widget data on disconnect/account/team changes, and show freshness/cached state.
- Demo widgets are Debug-only, isolated, and unavailable when a live token is present. Gallery examples never become live fallback values. See docs/widgets.md for verification and current release state.
- The later App Store image set must include genuine small/medium and large widget captures. Keep the flat inspection-sheet format without sequence numbers, concise deploy-focused captions and neutral/teal palette distinct from Codable's promotional imagery. Export through the attributed App Store image studio; preserve capture pixels and source aspect ratios.
- Current release notes and description include widget support at the user's request. Canonical store text is in `metadata/`; the user approved the descriptor, subtitle, keyword/description proposals and Developer Tools category in docs/app-store-discovery.md on 2026-10-12. Preserve the existing requested notes plus the widget paragraph. Metadata edits do not authorize resuming the withdrawn review.
- On 2026-10-12 the user separately authorized submitting 1.5.0 with all completed features. Include all widget sizes, Siri/Shortcuts, brief lifecycle improvements, native review cadence, comparison/history, UI and centered icon C. Track the actual build/submission state in docs/release-1.5.0-42.md; the previous withdrawal is historical.

## Siri, Shortcuts and brief lifecycle

- Keep App Intents useful and read-only: fresh deployment status, project inspection, site-health explanation and navigation. Deployment mutations always remain in the app's confirmed workflow.
- Status returns spoken/composable text from one bounded live GET. Empty Project means All projects for status and the current site for inspection/health. Never silently broaden a removed project or speak cached status as a fresh success.
- Project entities resolve from the current host-owned, secret-free catalog. Refresh shortcut parameters when that catalog changes. Require authentication for project evidence; execute intents in the main app process.
- Queue typed routes until an active scene finishes restoration. Consume once, validate account/team and recheck selection after awaits. Preserve existing intent type identifiers for saved shortcuts.
- Reuse accepted AI brief bodies only for identical bounded evidence in the same account/team/project, in memory for at most five minutes and six entries. Coalesce identical in-flight checks; cancel obsolete generation on site changes and clear reuse on disconnect, reconnection, team changes or model unavailability. Keep the heuristic usable without blocking navigation.
- See docs/siri-and-shortcuts.md and docs/apple-intelligence.md for actions, privacy, validation and physical-device verification limits.

## Review prompts and discoverability

- StoreKit requests follow anonymous device-local use: three separate inspection days, at least seven days since first successful use and a 120-day request cooldown. Never prompt at launch, in Demo/Debug, over comparison or confirmation UI, while busy, or after scope changes. Counts do not depend on positive site state or user sentiment. See docs/review-prompts.md.
- The product/support pages are published at https://www.jeremycollins.net/taktung and /taktung/support in the separate JeremyCollinsDotNet repo. App Store Connect confirmed 1.5.0 live on October 17. Keep later features labeled until their own App Store release is live. Do not resume review because website or metadata changes ship.
