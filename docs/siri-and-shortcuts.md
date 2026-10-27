# Siri and Shortcuts

Local 1.5.0 (42) adds three task-oriented actions alongside the existing navigation shortcuts. All use App Intents and the `TaktungShortcuts` provider. Settings → Siri & Shortcuts links to the system app.

| Action | Behavior | Empty Project |
| --- | --- | --- |
| Get Deployment Status | One fresh Vercel request; returns text for Siri and subsequent shortcut steps | All projects in the connected workspace |
| Inspect Project | Opens Home in the chosen project's scope | Current site |
| Check Site Health | Refreshes project metadata and the chosen site's deployments, then publishes the heuristic brief and optional on-device rewrite | Current site; opens the site picker if none is selected |
| Open Home | Opens Home | — |
| Open Deployments | Opens Deploys | — |
| Open Field Log | Opens Activity's local evidence journal | — |

Example phrases are “Check deploy status in Taktung,” “Check [project] deploy status in Taktung,” “Inspect [project] in Taktung,” “Check [project] health in Taktung,” and “Open the field log in Taktung.” Project phrases depend on the connected catalog and Siri's resolution. Saved shortcuts expose a native optional Project parameter. Existing Home/Deploys/Activity intent type identifiers and prior phrases are preserved.

Status describes the **newest created deployment across targets**, including preview or production when supplied by Vercel. Counts cover the **20 most recent deployments** rather than lifetime totals. A failed refresh returns a friendly error; it never speaks a last-good cache as a fresh success. Site health explains loaded deployment/project signals; it does not probe website uptime. Deployment mutation still requires the app's existing confirmation workflow.

## Scope and architecture

`ProjectEntity` and `ProjectQuery` resolve names from the host-owned secret-free system catalog. The shared `SystemProjectCatalog` helper also serves widget configuration without changing the widget entity's installed identity. Catalog updates call `updateAppShortcutParameters()`. Queries do not make network requests. Removed IDs are omitted and cannot silently broaden to All projects.

`ShortcutDeploymentStatus` reuses the widget's bounded deployment request and mapping. It requires a live connected context, then checks account/team revision, credential continuity and project availability after the response before publishing text or saving a last-good widget summary. Demo data cannot answer a live status request. Error messages omit credentials and raw server response text.

Intents execute in the main app process. Project evidence actions require system authentication; Open Home only navigates. Inspect/Health handoffs capture account/team when a project is specified. `TaktRouter` retains the latest typed route until an active Root scene completes connection restoration, consumes it once, and replaces the former transient notification. Workspace changes and manual site selection cannot apply an obsolete health result. A handoff dismisses Settings/site-picker overlays, abandons any unconfirmed mutation and resets the destination navigation stack to its root. Widget links and Search navigation use the same router. Only known `takt://` destinations are accepted; no URL can execute a mutation.

## Verification

- Debug simulator build and unsigned Release generic-device build succeed with Xcode 27.1.
- Extracted App Intent metadata includes all six actions, the `ProjectEntity`/`ProjectQuery` binding, six shortcut tiles, project parameters and app-name phrases. Receipts are under `.asc/qa/shortcuts/`.
- A real iOS 27 Simulator Shortcuts pass verified the Settings link, Taktung's Apps collection and all six action groups, named-project suggestions, Inspect Project selecting `example-blog.app` and dismissing an already-open Settings sheet, Site Health selecting `example-docs.app` and publishing its heuristic, and the expected connection error for status with no live token. After terminating Taktung, Open Field Log cold-launched into Activity rather than Home. The named fixtures are explicitly Demo evidence, not connected-account validation. Captures are in `.asc/qa/shortcuts/`.
- The full regression run passes 112 tests, zero failures/skips: `.asc/artifacts/test-shortcuts-final-42.xcresult`. Eleven shortcut tests cover fresh scoped status, All projects, demo isolation, removed projects, authentication failure, workspace/token changes, entity name resolution, actual intent handoff, single consumption, heuristic health routing and dismissal of overlays/unconfirmed plans.
- Simulator tests do not verify spoken Siri resolution or Apple Intelligence performance on physical hardware. A connected-device pass remains part of the later release checks: invoke generic and named-project phrases, run saved shortcuts from a cold app, switch teams, and compare returned text against Vercel.

No upload or resubmission occurred during the initial implementation. The later explicit submission authorization includes every action in 1.5.0 (42), now WAITING_FOR_REVIEW. Exported metadata verifies all six actions and the widget project entity; see [release details](release-1.5.0-42.md).

Apple references: [App Intents](https://developer.apple.com/documentation/appintents/app-intents), [AppIntent](https://developer.apple.com/documentation/appintents/appintent), [authentication policy](https://developer.apple.com/documentation/appintents/intentauthenticationpolicy/requiresauthentication).
