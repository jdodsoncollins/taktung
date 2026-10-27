# Taktung 1.3.0 (36)

Submitted October 10, 2026 at 5:29 PM Pacific. App Store Connect confirms **WAITING_FOR_REVIEW** for the version and its review submission. Release type is **AFTER_APPROVAL**. The prior 1.2.0 (35) release is live.

Exact update notes: **Rendering speed improvements. iPhone Duo support**

| Resource | Identifier |
| --- | --- |
| App / bundle | `6805738660` / `com.jcollins.takt` |
| Version | `3974f9d3-e054-40fe-b501-d4e7f3f5ad6f` |
| Build | `583f2609-1d37-4812-bdaf-295a66c95cfd` — 36, VALID |
| Review submission | `cd7b7750-da46-44e8-843c-da2fbbb231b0` |
| en-US localization | `e827690b-b0da-4866-9e1f-8cc0f82e3218` |

## Included behavior

Deployment Compare captures actual anonymous WebKit pages at a fixed viewport, with Reveal, Side by side, expanded inspection and saved route baselines. Commit, deployment, path and capture time identify each image. Capturing does not send the Vercel API token or browser cookies to the page.

Activity is a persistent Field Log: native daily sections, site scope, event filters, search, notes, full entry details and export. A restrained copper rail gives it Taktung's visual identity while preserving familiar activity-log interactions. New events preserve the reader's position and appear behind a new-entry button when reading older records. Failed note writes can be edited and retried without duplicating the note.

History and baselines are separated by account/team and demo/live scope. The release also includes the reviewed account-switching, stale-response, log-error and thumbnail-callback fixes described in [quality review](quality-review.md). Native adaptive workspaces and Duo state preservation use the iOS 27.1 SDK; minimum deployment is iOS 27.0.

## Verification

- Full suite: **67 passed, 0 failed, 0 skipped**; no compiler warnings or errors. Result bundle: `/Users/jeremycollins/Library/Developer/XcodeBuildMCP/workspaces/taktung-707327848c8d/result-bundles/test_sim_2026-10-10T23-54-26-544Z_pid82115_bd666161.xcresult`. Public summary: `.asc/qa/tests-1.3.0-summary.json`.
- The final scroll-inset correction was subsequently built and exercised through the native older-entry/new-entry flow. Signed Release archive and IPA export succeeded. The store binary is 1.3.0 (36), SDK 27.1, demo mode off, device families iPhone and iPad, with no compatibility or full-screen requirement key.
- Native checks covered compact and large iPhone, iPad, and Duo inner/outer portrait and folding/orientation changes. Real demo pages rendered visibly different comparison images. Expanded review, side-by-side mode, baseline saving, note creation, entry detail, event filters, restart restoration and stable reading position were exercised. The largest Dynamic Type size received a Duo-cover smoke check.
- A separate live session used the existing reviewer credential to load real projects and the selected site's deployments. Compare captured the production candidates `2dfb8ce` and `b9afe42` on the user's public site, with the correct route/commit/time provenance. Saving a local baseline selected Saved baseline; baseline and comparison events remained in the journal after relaunch. Search with no matches and Reset filters restored the records. On disk, demo and live journals remained separate and the live baseline persisted. No Vercel mutation was executed.
- Native Home Screen inspection confirmed the cream/copper Default icon and iron/mint Dark icon. Evidence: `.asc/qa/icon-home-light-1.3.0.png`, `icon-home-dark-1.3.0.png`. Icon assets retain the previously verified appearance specialization repair.
- Submission readiness: **0 blocking issues**, with IPA device-family and public URL checks. The remaining advisories concern existing keyword overlap, the existing support URL's intentional `www` redirect/site root, and API-only App Privacy visibility. Apple accepted the submission. The dry run and final attached version both match build 36; the exact release notes and updated feature description were verified remotely.

Simulator smoke tests do not establish physical-device endurance, full VoiceOver coverage or a measured rendering benchmark. Live protected-page authentication redirects and cancellation/timeout behavior are not exhaustively exercised; route/origin restrictions and privacy boundaries have domain tests. Anonymous protected pages report unavailable rather than receiving credentials. These limits remain explicit in the product and review notes.

## Listing artwork

Used the `asc-shots-pipeline` workflow for settings, review manifest, approval, upload plan/apply and remote verification. Native CUA prepared the screens; simctl captured the genuine displays. The experimental local asc capture runner was not used.

**34 RGB posters in five canvas formats** are COMPLETE in App Store Connect: eight large iPhone, eight standard iPhone, eight iPad, eight Duo inner and two Duo outer. Ten fresh posters show Field Log and visual comparison. The 24 unchanged posters retain their reviewed 1.2.0 artwork. Every remote source checksum matches the reviewed release file.

The large iPhone upload requests `APP_IPHONE_69`; App Store Connect returns the accepted 1320 × 2868 set as `APP_IPHONE_67`. Both Duo canvases share the ten-image `APP_IPHONE_DUO` set. No simulated display resizing or app UI retouching was used. Fictional notes stay exclusively in demo journals, and live smoke images are separate from marketing.

Editable project, real sources, capture trace, renderer, hash validation, review approvals and gallery: `artifacts/app-store-1.3.0-36/`. Artwork ZIP: `exports/Taktung-AppStore-1.3.0-36.zip`. Gallery: `public/gallery/index.html`. New-slide overview: `new-slides-contact-sheet.jpg`.

## Release receipts

Signed archive: `.asc/artifacts/Taktung-1.3.0-36-release.xcarchive`. Export: `.asc/artifacts/Taktung-1.3.0-36.ipa`. Signing reuses the existing distribution identity and profile in a dedicated local keychain; protected passwords/private identity material remain outside the repository.

Public receipts under `.asc/qa/`: `archive-1.3.0.json`, `export-1.3.0.json`, `build-1.3.0-info.json`, `screenshots-1.3.0-plan.json`, `screenshots-1.3.0-applied.json`, `screenshots-1.3.0-remote.json`, `validation-1.3.0.json`, `review-1.3.0-dry-run.json`, `review-1.3.0-submit.json`, `review-1.3.0-status.json` and `review-1.3.0-submission.json`. Reviewer access instructions were retained and supplemented with Compare/Field Log test steps; sensitive notes are not in this report or the artwork package.

Monitor with `asc review status --app 6805738660 --version 1.3.0 --output json`, or open [App Store Connect](https://appstoreconnect.apple.com/apps/6805738660/distribution/ios/version/inflight).
