# Home Screen widgets

Local 1.5.0 (42) adds the **Deployment status** WidgetKit extension in small, medium and large sizes. Every family defaults to **All projects** in the connected account/team workspace. Touch and hold a widget, choose **Edit Widget**, then choose **Project** to pin that widget to one project. Each widget's filter persists independently of the app's selected site. The widget follows system light/dark appearance, including when the app forces another appearance.

The small widget stacks the scope, most recent deployment state, counts and freshness. The medium widget adds the latest target and sample size beside the counts. The large widget shows the latest five deployment records, or three at accessibility text sizes, with project, current status, target and creation time. **Recent deploys** describes records from the same bounded response; it is not a status-transition history or raw build log and adds no network calls.

## Durable visual rules

This is an ordinary extension of [DESIGN.md](../DESIGN.md), with WidgetKit supplying its native surface behavior. The shared design file and sidecar remain unchanged.

- **System appearance:** read the widget's color scheme and rendering mode, independently of the host's System/Light/Dark setting. Use the opaque semantic widget ground; let WidgetKit own shape, margins and configuration materials. Content adds no glass, custom shadows or decorative charts.
- **State with evidence:** keep the order scope → latest state → counts → recent records → freshness. Ready uses restrained adaptive teal; failure and active states use the existing semantic color families. Every status has a word and SF Symbol. Tinted/accented rendering uses primary foreground rather than relying on color.
- **Readable supporting ink:** project metadata, count labels, timestamps and neutral Canceled/Deleted/Unknown labels use `secondaryText` (`.primary.opacity(0.75)`). Do not restore default `.secondary` for these small captions: it failed the actual light widget ground's contrast check. This semantic widget rule does not add fixed global color tokens.
- **Stable time:** latest creation time and freshness use compact 24-hour clock text for the same day, or a compact date for earlier days. Avoid second-granularity relative copy; retain full spoken timestamps and Checked/Cached meaning. Demo provenance stays visible.
- **Fixed-area reading:** use SF text styles and tabular count digits. Small/medium accessibility layouts stack labeled counts and reduce optional detail. Large reduces five records to three at accessibility sizes. Widget text grows through xxxLarge; VoiceOver retains full timestamps and the sample total. Do not turn this widget-specific cap into an app-wide Dynamic Type limit.

## Meaning of the data

- **Latest** means the newest created deployment across targets in the selected widget scope, not the current production alias.
- Counts cover at most the **20 most recent deployments**. Ready includes READY. Failed includes ERROR, BLOCKED and CANCELED, consistent with the app's attention filter. Building includes BUILDING, INITIALIZING and QUEUED. Other/unknown states can make the three counts sum to less than the sample total.
- **All projects** uses one workspace-wide deployment request. A specific filter adds `projectId`. No per-project deployment fan-out is introduced into Home or the site picker.
- The checked time is the last successful fetch or host snapshot. An unsuccessful refresh retains last-good data labeled **Cached**; authentication failure shows a reconnect instruction instead of counts. A removed project shows an unavailable message and never silently becomes All projects.
- The extension requests another timeline after 15 minutes. iOS owns the actual schedule; this is not a guaranteed interval or real-time monitor. Host project/deployment refreshes ask WidgetKit to reload.
- A widget tap opens the app's Deploys tab. It currently preserves the app's selected site.

## Implementation and privacy

`TaktungWidgets` is an embedded extension with bundle ID `com.jcollins.takt.widgets`. `DeploymentWidgetConfiguration` is a `WidgetConfigurationIntent`; `WidgetProjectEntity` and `WidgetProjectQuery` provide the native picker and default All entity. The query reads the host's bounded project catalog and performs no network requests.

`WidgetDeploymentSnapshot` is the bounded secret-free summary shared with the app. It sorts/deduplicates deployments, caps the sample at 20, and carries account/team/project scope, an account revision and freshness. `WidgetAccountContext` stores the host-owned project catalog and seed snapshots. `WidgetDeploymentService` performs only `GET /v7/deployments`, with a 15-second timeout, limit 20 and the selected team/project filters. Its DTO maps state/name/date/target only; arbitrary deployment metadata and environment values are excluded.

The app and extension join the host's existing device-only Keychain group `$(AppIdentifierPrefix)com.jcollins.takt`. The extension reads the existing PAT; it does not copy it into shared preferences or files. Context and per-filter last-good summaries use separate records, with cache service `com.jcollins.takt.widget-cache`. The host clears context/cache and replaces the account revision on account/team/token changes or disconnect. App site changes do not change a widget's filter. Responses recheck account revision, token and project availability before publication. Cache keys include revision and project; an extension cannot overwrite the host context.

Debug demo widgets use isolated fixture records, marked Demo, and are refused when a live token exists. Release widgets never read demo context. Gallery samples are separate preview-only data and are never a fallback for a live session.

## Verification, October 12, 2026

The latest domain regression run passes **95 tests, zero failures and zero skips**, including 14 widget tests for count semantics, newest deployment, sample bounds, bounded recent records, backwards-compatible cache decoding, All/specific request mapping, DTO privacy, removed filters, scope changes and Keychain/cache isolation/erasure. This run preceded the final neutral-status foreground and static gallery-fixture correction. The final source then passed fresh Debug Simulator and unsigned Release generic iOS builds, with no compiler warnings reported. The unsigned device build does not establish distribution provisioning or physical widget operation.

Genuine native Home Screen captures use owned iPhone 17 Pro and iPad Pro 13-inch M5 simulators on iOS/iPadOS 27.0. All three families were installed and checked in light/dark and at accessibility5. The 15 required captures passed the full native review; large shows five complete records normally and three at accessibility sizes on both device classes. Widgets followed system Dark while the host forced Light. The native long-press **Edit Widget** action was exercised: the picker defaulted to All projects, and selecting example-blog changed its counts to 1 Ready / 0 Failed / 0 Building while the independent All widget retained 19 / 1 / 0. Filters survived reinstalling build 42. These are explicitly Demo fixtures, not connected-project or live-performance evidence.

The [full large review](../.impeccable/review/widgets-large-finish-review.md) found one remaining neutral-status contrast gap. Its [scored-fix verdict](../.impeccable/review/widgets-large-finish-verdict.md) is **ship** after `secondaryText` replaced `.secondary` for Canceled, Deleted and Unknown. Two genuine iPad WidgetKit gallery captures cover those caption-sized states: modal interior glyph samples against the local ground measured **9.81:1 in light** and **6.85:1–7.37:1 in dark**, exceeding 4.5:1. These are gallery-render measurements; the original Home Screen captures remain layout evidence. The earlier [small/medium verdict](../.impeccable/review/widgets-finish-verdict.md) resolves compact freshness and metadata contrast. A design ship verdict does not establish store distribution.

Evidence is under `.impeccable/review/widgets-*.png`; the [surface brief](../.impeccable/surfaces/taktungwidgets-taktungwidgets-swift.md) and [documentation report](../.impeccable/review/widgets-documentation-report.md) record the design boundary. Build/test/withdrawal receipts are under `.asc/qa/widgets/` and `.asc/qa/review-1.5.0-41-widget-*.json`. The final test result is `.asc/artifacts/test-widgets-large-42.xcresult`; its summary is `.asc/qa/widgets/large-test-summary.json`. The post-fix compile logs are `.asc/qa/widgets/contrast-build.log` and `contrast-device-build.log`.

The build-42 listing package has 25 browser-rendered posters, including genuine small/medium widget sheet 03 and large Recent deploys sheet 04 for each phone/iPad set, plus refreshed Settings captures. It retains the flat numbered inspection-sheet format, neutral/teal palette and source capture aspect ratios, with 16 unchanged feature captures preserved. [App Store imagery](app-store-imagery.md) records the attributed studio, source trace and inspection limits. All 25 images were uploaded and verified during the later authorized submission.

## Release state

Build 41's review request was cancelled and verified COMPLETE. The user then authorized submitting all completed features on 2026-10-12. Build **42 is VALID and WAITING_FOR_REVIEW**, with small, medium and large widgets included. The widget bundle is registered/provisioned, exported host/extension signatures and shared Keychain entitlements verify, and all 25 listing assets are COMPLETE with matching checksums. Release is automatic after approval. Physical background refresh, live widget UI and tinted Home Screen UI remain unverified. Current release notes, description, signing details, submission IDs and monitoring are recorded in [the release record](release-1.5.0-42.md) and canonical `metadata/`.
