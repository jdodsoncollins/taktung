# Taktung 1.7.0 (44)

Historical record: this submission was later withdrawn. The editable version is now the unsubmitted [1.7.1 (45) preview-release draft](release-1.7.1-45.md), verified October 21, 2026. The submission evidence below describes the earlier October 20 event.

**1.7.0 (44) is WAITING_FOR_REVIEW**, submitted October 20, 2026 at 16:50 America/Los_Angeles, with automatic release after approval. Build 44 is also VALID and available in internal TestFlight. The user authorized the new minor App Store release, Analytics metadata and refreshed number-free images. This is not yet a public App Store release.

## Included

- Home → Project tools → Analytics: visitors, page views, daily traffic and Pages, Referrers, Countries or Devices breakdowns for the selected project/team. Seven/30-day completed UTC windows are labeled with actual returned bounds. Plan, instrumentation, permission, network and empty states remain distinct.
- Native Swift Charts, accessible daily-value disclosure, Light/Dark/System appearance, adaptive phone/tablet layout and Dynamic Type.
- Settings → Other Apps: Codable, TabForge and Paper & Grain, with published icons, app descriptions, detail pages and App Store links.
- All previously released inspection tools, redacted logs, widgets in all three sizes, read-only Siri/Shortcuts, visual comparison, Field Log, adaptive Duo workspace and centered layered icon C.
- Analytics description/release notes and 31 number-free listing images, including three new Analytics compositions. Existing headline/caption wording remains unchanged.

Architecture and limitations: [Web Analytics](web-analytics.md), [Other Apps](other-apps-catalog.md), [listing provenance](app-store-imagery.md).

## Build and distribution

| Field | Verified value |
| --- | --- |
| App | `6805738660`, `com.jcollins.takt` |
| Platform | IOS |
| Version / build | `1.7.0` / `44`, matching host and widget |
| Build ID | `1f09eec6-38ef-458e-ab2c-41282325bb15` |
| Apple processing | `VALID` |
| Internal TestFlight | `IN_BETA_TESTING` |
| App Store version ID | `e43d9961-f4ff-4cf4-a89e-b0a02463fa63` |
| App Store state | `WAITING_FOR_REVIEW` |
| Submission ID | `ffef0900-7716-4968-8c94-4d9494fe878f` |
| Submitted | `2026-10-20T23:50:43.637Z` |
| Release type | `AFTER_APPROVAL` |
| Existing internal group | `Team (Expo)`, `969268ca-e12f-47b5-aba7-79659a1b9f28` |
| Group access | Existing all-build access verified; no new invitations or external beta submission |
| Minimum OS | iOS 27.0, host and widget |
| IPA | 5,011,712 bytes |
| IPA SHA256 | `390766b53f3c7ec4f632c4f7fb802c71e10b3c28d8784e066431e2fcb8a5b082` |

Xcode 27.1 archive and export succeeded. Both signatures pass strict verification, `get-task-allow=false`, and the existing device-only Keychain group `3WN8R7X4QL.com.jcollins.takt` remains unchanged. Demo/test credentials are absent from the signed artifact. Archive, IPA and export settings are under `.asc/artifacts/` and `.asc/ExportOptions-1.7.0-44.plist`.

The previous Release profiles selected an old distribution key held in locked `release-13`, causing a password prompt. The existing Apple Distribution identity in the normal login Keychain was independently verified to sign without a prompt. New host/widget App Store profiles were created for that existing certificate, with the same team, bundle IDs and capabilities. Release settings and export now select those profiles explicitly. No certificate was revoked, password changed, or Keychain protection weakened. Public profile IDs: host `6946897DMR`, widget `X8LHF37S7W`; certificate resource `YC5U3Z7Q2D`.

## Verification

- Full regression: **140 passed, zero failures/skips**. Subsequent session regression: **12 passed**, including one new delayed Analytics response scope test. Together: **141 distinct tests**.
- Native transport fixtures cover authenticated routing, project/team/environment filtering, effective date alignment, non-additive visitors, reconciliation, invalid counts, repeated days, redaction and permission/rate-limit failures.
- Simulator inspection covered compact/large iPhone and iPad, Light/Dark, seven/30-day switching, referrer selection and the largest accessibility text size. Other Apps icons, layout and destinations were checked. No physical-device or Apple Intelligence performance claim is made.
- Authenticated Vercel connector evidence for jeremycollins.net, October 13–19 UTC: **153 page views, 67 visitors**. Daily and all four breakdowns reconcile to 153 page views for the same effective window. Native transport uses deterministic URLProtocol tests; marketing captures use isolated Demo. A direct live native PAT session was not independently reauthenticated in this pass.
- All 31 final exports were visually checked. The initial standard-phone export had blank device screens; after the source screens visibly loaded, it was re-exported and reviewed again. Only populated, corrected exports were approved. Numbers remain absent from artwork; editor navigation counters are not exported.

Receipts and native captures: `.asc/qa/release-1.7.0/`. Five fresh build44 source files supply six image placements. The remaining 25 placements retain representative verified build41/42/43 captures; hashes/build origins are preserved. Marketing fixtures never mix with live sessions.

## Canonical release notes

New: Vercel Web Analytics in Project tools. Check visitors, page views and daily traffic, then explore top pages, referrers, countries and devices for your selected project.

Other Apps now includes Codable, TabForge and Paper & Grain, with updated icons and app details.

Rendering speed improvements. iPhone Duo support. Bug fixes and UI updates.

Small, medium and large Home Screen widgets show deployment status and recent activity, with an optional project filter.

Canonical text: `metadata/version/1.7.0/en-US.json`. Approved app descriptor/subtitle and Developer Tools category remain unchanged. Existing reviewer contact and access are preserved.

## App Store submission and imagery

The existing processed build44 was staged, metadata applied and the intended build attachment verified. Canonical and remote en-US metadata match exactly. The screenshot upload replaced the inherited set with **31 COMPLETE assets**; every remote MD5 source checksum, dimension and order matches its reviewed local export. The generic screenshot planner's focused 6.5-inch advisory is covered by the accepted large-phone set; final strict readiness reports **zero errors, zero warnings and zero blockers**.

The API gives an informational App Privacy publication advisory because it cannot verify that state publicly. The existing published Data Not Collected label and collection behavior remain unchanged; Apple's final submission accepted the release. No App Store account-preview verification or physical-device performance claim is made.

The dry run selected the correct already-attached build and returned `wouldSubmit=true`. The confirmed submission succeeded, and subsequent review/version reads both report WAITING_FOR_REVIEW. A direct version resource read confirms AFTER_APPROVAL and the exact build ID. No duplicate submission was created. Existing reviewer contact/access remained unchanged; no token from review notes was reused for testing.

Image source trace, attribution, review manifest/approvals, contact sheet, preview and ZIP: `artifacts/app-store-1.7.0-44/`. Gallery: <http://127.0.0.1:52530/gallery/index.html>. A copied gallery asset directory initially showed older files; it was replaced with a link to the reviewed exports and the local server restarted. The visible gallery now shows the number-free images. This did not affect reviewed/uploaded files.

Receipts: `.asc/qa/release-1.7.0/release-status.json`, `review-submitted.json`, `review-verified.json`, `version-release-verified.json`, `screenshots-checksum-proof.json`, `submission-validation.json` and `metadata-verified/`. Monitor with:

```sh
asc review status --app 6805738660 --version 1.7.0 --platform IOS --output table
```
