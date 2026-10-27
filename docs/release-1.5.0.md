# Taktung 1.5.0 (41)

**Withdrawn at the user’s request on October 12, 2026.** Submission `3b5833b8-9dd6-47c6-890f-0a16c456f9f7` is COMPLETE after cancellation, and the version is DEVELOPER_REJECTED (developer withdrawal). Configurable WidgetKit support is implemented in local build 42, with 95 passing domain tests and simulator UI evidence. Build 42 has not been uploaded or resubmitted. See [widgets](widgets.md). The evidence below preserves the original build 41 submission.

At the original submission on October 12, 2026 at 07:27 PDT, App Store Connect confirmed **WAITING_FOR_REVIEW** for version 1.5.0 with build **41** and review submission `3b5833b8-9dd6-47c6-890f-0a16c456f9f7`. Release type remains **AFTER_APPROVAL**. That submission was later withdrawn as recorded above. The evidence below is historical; it is not a pending review.

Exact What's New, unchanged: **Rendering speed improvements. iPhone Duo support. Bug fixes and UI updates.**

| Resource | ID |
| --- | --- |
| App | 6805738660 |
| Version | 64c6ef2d-6697-4c10-a686-e3f7f3c60a44 |
| Build 41 | 242b4cbf-1a5a-4c76-a64d-5929adc5b6ab |
| Review submission | 3b5833b8-9dd6-47c6-890f-0a16c456f9f7 |
| en-US localization | a6e22430-ea8a-4c48-bd14-c4675458c07a |

## Centered selected C

The user requested the same abstract metronome with a centered body and base. All three frame SVGs now share x=512 on the 1024 px source canvas. Body mirror pairs sum to 1024; the 652 px base spans x=186–838. The pendulum, counterweight, background fills, palette and independent layer arrangement are preserved. Local clearance remains 10 px beyond the pendulum edge and counterweight disk, preventing contact after moving the frame. The complete mark retains the intended directional pendulum. Exact coordinates are in `.asc/qa/icon-1.5.0-41/centering-proof.json`.

`Taktung/AppIcon.icon` remains a standard Icon Composer document with eleven editable SVG sources in three appearance groups: background, frame, pendulum and counterweight for Default/light and Dark; three system-tinted foreground parts. Source artwork contains no baked app mask, gloss, lighting or shadow. The previous geometry and Settings assets remain in `artifacts/icon-c-1.5.0-41/`; the original selected-C studies and build40 archive remain retained.

## Verification

- Apple Icon Composer ictool parsed/rendered Default/light, Dark and TintedDark for design generation 27, plus 120 px small previews. The native Icon Composer GUI reopened the corrected document and showed the centered artwork and editable layers.
- Signed Xcode simulator build, release archive and IPA export succeeded without compiler warnings/errors. App Store Connect processed build41 as **VALID** and App Store eligible; Apple's processed 152 px icon was downloaded and visually verified.
- Derived `TaktungMark` Default/light and Dark assets match verified Apple render pixels exactly, with embedded origin records. Native iPhone and iPad Settings captures show the corrected icon in light/dark, including forced in-app appearance. The installed Home Screen Dark glyph was inspected. Home Screen appearance remains system-owned.
- A fresh independent reviewer returned **ship**, with no material fixes; a fresh documenter recorded the shared center and construction rules in DESIGN.md and its sidecar. Evidence: `.impeccable/review/icon-c-center-packet.json`, `icon-c-center-review.md`, `icon-c-center-verdict.md`.
- This correction changes icon/derived artwork and build number, with no runtime/domain behavior changes. The signed **81-test regression pass from build40** remains recorded in [the original build40 release record](release-1.5.0-40.md). It was not rerun for this static artwork correction. No new physical-device performance or Dynamic Type regression claim is made.

The minimum remains iOS 27.0, built with Xcode 27.1 / iOS 27.1 SDK. Broader connected-project, real comparison, Field Log, Search and bounded local-summary evidence remains in [1.4.0](release-1.4.0.md) and [UI regression notes](ui-refresh-2026-10-11.md). Physical Apple Intelligence latency and physical Duo gesture/posture performance remain unverified.

## Updated listing

Three icon-bearing listing sources were refreshed from two verified native build41 captures: iPhone 17 Pro Settings at 1206×2622 and iPad Settings at 2064×2752. The genuine iPhone capture is used on both phone marketing canvases with its original aspect preserved. Large-phone simulator input did not open Settings through the mirror's legacy HID path; its Home captures are excluded from Settings evidence. No app pixels were retouched. Sixteen unchanged feature captures remain representative of the unchanged interface.

All nineteen posters were freshly exported using the attributed editor's existing browser renderer, preserving the flat numbered inspection-sheet style and captions. A cached large-phone source was discovered during inspection, the editor was reloaded, and that deck was exported again before approval. The final inspected large Settings poster shows the current centered icon.

| Marketing canvas | Size | Posters | App Store display set |
| --- | --- | --- | --- |
| Large iPhone | 1320 × 2868 | 5 | APP_IPHONE_67 |
| Standard iPhone | 1206 × 2622 | 5 | APP_IPHONE_61 |
| iPad | 2064 × 2752 | 5 | APP_IPAD_PRO_3GEN_129 |
| Duo inner | 2007 × 2853 | 2 | APP_IPHONE_DUO |
| Duo outer | 1398 × 2034 | 2 | APP_IPHONE_DUO |

All **19 remote screenshots are COMPLETE**, with source checksums matching the approved local files. An authentication error stopped the first upload after the iPad group; completed images were inspected, the remaining groups were uploaded separately, and all final checksums were verified before submission. Smaller compatible devices inherit App Store artwork. The focused APP_IPHONE_65 planner advisory remains nonblocking. Final readiness reported **0 errors / 0 blocking issues**, two existing keyword-overlap warnings and a public-API privacy-publication advisory.

The current [public Apple listing](https://apps.apple.com/us/app/taktung/id6805738660) publishes **Data Not Collected**. The authenticated browser session was unavailable; no draft privacy answers were inspected or changed. This icon correction changes no data handling. The API advisory remains accurately recorded; the final submission succeeded.

The [artwork ZIP](../artifacts/app-store-1.5.0-41/exports/Taktung-AppStore-1.5.0-41.zip), editable project, source trace, approved PNGs, review and gallery are in `artifacts/app-store-1.5.0-41/`. The studio's configured loopback URL is `http://127.0.0.1:52527`, with gallery `/gallery/index.html`. Packaging validates/packages existing browser exports; it does not render or retouch app UI.

## Supersession and receipts

The exact pending build40 review submission `cc86cfa3-22c4-4e3d-ae87-f2d73fc7d678` was inspected as WAITING_FOR_REVIEW, cancelled and verified **COMPLETE** before build41 was attached. The same 1.5.0 version record, release notes, review metadata and automatic release policy are preserved. [Build40's original record](release-1.5.0-40.md) remains for history; its submission is superseded.

Final receipts: `.asc/qa/build-1.5.0-41-valid.json`, `review-1.5.0-41-dry-run.json`, `review-1.5.0-41-submit.json`, `review-1.5.0-41-status.json`, `version-1.5.0-41-after-submission.json`, `versions-1.5.0-41-final.json`, `validation-1.5.0-41.json`, `screenshots-1.5.0-41-checksum-proof.json`, `privacy-1.5.0-41-publication.json`, and `release-1.5.0-41-status.json`.

Monitor with `asc submit status --id 3b5833b8-9dd6-47c6-890f-0a16c456f9f7`.
