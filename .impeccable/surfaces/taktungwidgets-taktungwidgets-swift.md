---
version: 1
slug: "taktungwidgets-taktungwidgets-swift"
primary_target: "TaktungWidgets/TaktungWidgets.swift"
related_targets: ["TaktungWidgets/WidgetProjectConfiguration.swift","Taktung/Domain/WidgetDeploymentSnapshot.swift","Taktung/Services/WidgetDeploymentService.swift","Taktung/Services/WidgetSnapshotStore.swift","Taktung/Features/SettingsView.swift"]
---

# Home Screen deployment widgets

Mode: Operate. Ordinary extension of Taktung's current neutral/teal system.
Native code first, as the user selected for the app. No new visual-world decision or generated mockup.

## Direction contract

THESIS: A glance answers what happened most recently and whether recent deploys need attention.

OWN-WORLD: System widget background, semantic SF text and symbols, restrained adaptive teal for Ready. WidgetKit owns the mask, margins, configuration sheet and transitions. System appearance governs the widget independently of the app's override.

STORY: See the scope, newest deployment state, Ready/Failed/Building counts and freshness; tap to open Deploys. Long-press Edit Widget chooses an independent project filter, with All projects as default.

FIRST VIEWPORT: Small stacks project, latest status, three compact count columns and checked time. Medium puts latest evidence beside counts, with freshness below. Large adds five recent deployment records (three at accessibility sizes), with project, current state, target and stable creation time. Accessibility sizes stack labeled counts and prioritize state in the fixed widget area. Gallery/demo samples are explicitly marked.

FORM: Standard small, medium and large WidgetKit families; system AppIntentConfiguration project selection. Native OS constraints and explicit user instruction govern the arrangement; no decorative chart or custom configuration surface.

FINISH: documented October 12, 2026 after full native review and scored fixes. The broader [large-family review](../review/widgets-large-finish-review.md) validated all 15 required native captures and found one neutral-status contrast issue. The [scored-fix verdict](../review/widgets-large-finish-verdict.md) is ship after Canceled/Deleted/Unknown adopted `secondaryText`; actual gallery-render contrast is 9.81:1 light and 6.85:1–7.37:1 dark. The earlier [small/medium verdict](../review/widgets-finish-verdict.md) resolves compact freshness and caption contrast. This design disposition is independent of store release state: local build 42 is not uploaded or submitted.

## Recorded implementation rules

- System SF styles and tabular count digits preserve hierarchy; metadata and neutral statuses use semantic primary at 75% opacity. Default system secondary is not accepted for the reviewed caption roles because it failed on the real light widget ground.
- Latest and checked times use stable compact clock/date text, with complete timestamps in accessibility descriptions. Freshness keeps Checked/Cached meaning and Demo provenance.
- Small/medium stack labeled counts at accessibility sizes. Large retains five recent records normally and three at accessibility sizes on both iPhone and iPad. Text grows through xxxLarge within the fixed widget region; this limit is local to widgets.
- Read color scheme and rendering mode from the widget environment. The host's forced appearance does not determine widget theme. Non-full-color modes use primary foreground for state.
- Native AppIntentConfiguration chooses an independent project filter, default All projects. Unavailable project identity persists so removed filters cannot broaden silently.
- Widget records show bounded project/state/target/creation-time evidence. The extension provider fetches one scoped GET and writes only a per-revision/per-filter last-good cache; account context remains host-owned. No environment values or raw logs enter the summary.

These are surface rules within the existing design world. Shared `DESIGN.md` and `.impeccable/design.json` were preserved; no global palette, type, shape or motion changes were approved.

## Evidence boundaries

Counts sample the 20 most recently created deployments, across production/preview targets. They are not all-time totals or production alias health. All projects refers to the connected account/team workspace. Live requests use one bounded GET and no project fan-out. Simulator fixtures are Debug-only and unavailable with a live token; gallery samples are preview-only. Large Recent deploys is a list of current deployment records, not a historic transition log.

All 15 required Home Screen/configuration captures were validated by the native reviewer. Six large-family captures show five rows normally and three at accessibility5. Two additional actual gallery captures verify caption-sized neutral statuses in light/dark. The context-menu capture includes an OS keyboard and is affordance evidence only. The 95-test domain run preceded the view-only neutral-status fix; fresh post-fix Debug Simulator and unsigned Release generic builds passed. Simulator evidence does not establish live widget fetching, physical refresh timing, signed device provisioning or tinted Home Screen rendering.

Build 41 review is withdrawn COMPLETE and version 1.5.0 is DEVELOPER_REJECTED; local 42 remains unsubmitted. The staged 25-poster marketing package uses genuine small/medium sheet 03 and large sheet 04 captures in the distinct flat inspection-sheet format; no marketing upload occurred. [Widget documentation](../../docs/widgets.md) and the [documentation report](../review/widgets-documentation-report.md) retain the sources and limits.
