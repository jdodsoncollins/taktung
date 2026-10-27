# Taktung 1.5.0 (40)

Historical record: its pending submission was withdrawn and confirmed COMPLETE on October 12, 2026; build41 replaces it. See [current release](release-1.5.0.md). The paragraphs below retain the original build40 submission evidence.

Submitted October 11, 2026 at 20:59 PDT. App Store Connect confirms **WAITING_FOR_REVIEW** for version 1.5.0 and review submission `cc86cfa3-22c4-4e3d-ae87-f2d73fc7d678`. Release type is **AFTER_APPROVAL**. This is submitted, not yet approved or live; 1.3.0 (36) remains the current live version.

Exact What's New: **Rendering speed improvements. iPhone Duo support. Bug fixes and UI updates.**

| Resource | ID |
| --- | --- |
| App | 6805738660 |
| Version | 64c6ef2d-6697-4c10-a686-e3f7f3c60a44 |
| Build 40 | f0dc484e-3fee-4c87-ae7e-461bfca965ff |
| Review submission | cc86cfa3-22c4-4e3d-ae87-f2d73fc7d678 |
| en-US localization | a6e22430-ea8a-4c48-bd14-c4675458c07a |

## Selected C icon

The user selected C, the abstract metronome. `Taktung/AppIcon.icon` is a standard Icon Composer document containing eleven editable SVG sources: frame, pendulum, counterweight and background for Default/light and Dark, plus three independent system-tinted foreground parts. The same open-frame geometry and crossing clearance persist across appearances. Existing neutral/teal colors fit the refreshed app; source art contains no baked platform mask, gloss, lighting or shadows. The previous icon and approved three-concept board are retained in `artifacts/icon-c-1.5.0-40/`.

Apple Icon Composer ictool renders Default, Dark and TintedDark with design generation 27. The native Icon Composer GUI opened the document, showed all eleven layers in three groups, and displayed correct Default and Dark previews. Xcode compiled and archived it without compiler warnings/errors. Derived `TaktungMark` light/dark assets preserve the verified Apple renderer pixels with embedded provenance, and Settings follows the resolved System/Light/Dark app appearance.

## Verification

- Signed serial simulator regression: **81 tests passed**, no failures, skips or runtime warnings. `.asc/qa/tests-1.5.0-40-summary.json` and `.asc/artifacts/test-1.5.0-40-signed.xcresult` preserve results. Earlier unsigned runs lacked the Keychain application-identifier entitlement; they were interrupted and replaced by the successful signed run. No app/test behavior was changed to bypass that entitlement.
- Default/light, Dark and system-tinted Apple renders inspected, including 60 pt previews. Native compact/large phone and iPad Settings show the new icon; compact phone and iPad dark captures cover appearance switching. Home Screen captures show the system-selected Dark glyph on light and dark wallpapers. Default/light Home customization was not separately forced; Default/light is verified through Apple's renderer and native Settings.
- Fresh independent icon reviewer passed construction, selected-C fidelity, small-size recognition and Settings integration. Its stale identity-documentation finding was corrected and scored resolved. A fresh documenter synchronized durable identity guardrails while retaining existing palette, typography, spacing and content materials. Evidence: `.impeccable/review/icon-c-finish-packet.json`, `icon-c-finish-review.md`, `icon-c-finish-verdict.md`.
- App Store Connect processed build 40 as **VALID** and App Store eligible. Its Apple-hosted processed icon was downloaded and visually verified as selected C (`.asc/qa/icon-1.5.0/apple-processed-build-icon.png`). Archive/IPA, signing identifiers and upload receipts are retained under `.asc/`.

The broader native UI, connected-project regression, real comparison, persistent Field Log, Search and bounded local-summary evidence are recorded in [1.4.0](release-1.4.0.md) and [UI regression notes](ui-refresh-2026-10-11.md). The app minimum remains iOS 27.0 and the build uses Xcode 27.1 / iOS 27.1 SDK. Physical-device Apple Intelligence latency and physical Duo gesture/posture performance remain unverified; simulator captures do not establish them.

## Updated listing

All three icon-bearing Settings sources were recaptured in isolated native Demo sessions. Sixteen unchanged feature captures remain representative of the unchanged app UI. All nineteen posters were freshly exported through the attributed editor's existing browser renderer in the same flat numbered inspection-sheet format, distinct from Codable's marketing.

| Native canvas | Size | Posters | App Store display set |
| --- | --- | --- | --- |
| Large iPhone | 1320 × 2868 | 5 | APP_IPHONE_67 |
| Standard iPhone | 1206 × 2622 | 5 | APP_IPHONE_61 |
| iPad | 2064 × 2752 | 5 | APP_IPAD_PRO_3GEN_129 |
| Duo inner | 2007 × 2853 | 2 | APP_IPHONE_DUO |
| Duo outer | 1398 × 2034 | 2 | APP_IPHONE_DUO |

All nineteen remote screenshots are **COMPLETE**, with source checksums matching the approved local files. Smaller compatible devices inherit App Store artwork. The planner's focused APP_IPHONE_65 advisory does not prevent accepted large-phone inheritance; final readiness reports zero blocking issues. Two existing keyword-overlap warnings and the public-API privacy-publication advisory are retained in the readiness receipt. Submission succeeded.

The [artwork ZIP](../artifacts/app-store-1.5.0-40/exports/Taktung-AppStore-1.5.0-40.zip), source trace, reviewed PNGs, approvals and editable project are in `artifacts/app-store-1.5.0-40/`. The studio runs at `http://127.0.0.1:52526`; its gallery is `/gallery/index.html`. Packaging only validates/packages existing browser exports; it does not render or retouch app UI.

## Supersession and receipts

The exact pending 1.4.0 submission was inspected, withdrawn, and confirmed complete before the editable version record was renamed to 1.5.0. Build 40, the requested notes and updated screenshots replaced the pending materials. This preserves listing/review metadata and leaves the live version available. Original 1.4.0 submission `185bc9f1-9952-46f8-af1e-10639a4576d7` and build 39 are superseded. Old evidence and original artwork remain retained.

Final receipts: `.asc/qa/review-1.5.0-40-dry-run.json`, `review-1.5.0-40-submit.json`, `review-1.5.0-status.json`, `version-1.5.0-after-submission.json`, `versions-1.5.0-final.json`, `validation-1.5.0-final.json`, `screenshots-1.5.0-checksum-proof.json`, and `release-1.5.0-status.json`.

Monitor with `asc review status --app 6805738660 --version 1.5.0 --platform IOS`.
