# Taktung 1.4.0 (39)

Originally submitted October 11, 2026 at 18:49 PDT as **WAITING_FOR_REVIEW**. At the user's request it was withdrawn and superseded by [1.5.0 (40)](release-1.5.0.md) at 20:59 PDT. Its editable version ID now belongs to 1.5.0. This record preserves the original 1.4.0 implementation and evidence.

Exact What's New: **Rendering speed improvements. iPhone Duo support**

| Resource | ID |
| --- | --- |
| App | 6805738660 |
| Version | 64c6ef2d-6697-4c10-a686-e3f7f3c60a44 |
| Build 39 | 488503b6-851d-4f78-b1ce-6e3884091bec |
| Review submission | 185bc9f1-9952-46f8-af1e-10639a4576d7 |
| en-US localization | a6e22430-ea8a-4c48-bd14-c4675458c07a |

## Result

Production evidence and the next inspection task lead the refreshed native interface. Comparison is reachable from Home; deployment actions use native menus with hard confirmation. Light, Dark and System appearance persist and apply to sheets. Settings includes the adaptive app icon, and Other Apps has readable, spacious rows. Search results navigate to the selected site or matching deployment; canceled deployments have an honest distinct diagnosis. Persistent Field Log records remain intact while recognized legacy routine labels display in plain language.

Apple Intelligence availability refreshes on activation and before checks. The heuristic publishes immediately, while optional local summaries use one fresh bounded session, actual token counts, context headroom and a short output budget. The minimum remains iOS 27.0; build 39 uses Xcode 27.1 (27A9275) and its iOS 27.1 SDK.

## Verification

- Full regression suite: 79 tests passed, no failures/skips/compiler warnings. Ten focused Field Log/comparison tests then passed after the history display correction, including two new cases.
- Read-only live UI/API comparison matched five connected project states and commits. The exact reported hostname and canceled deployment opened the expected site/detail. No live deployment mutation was executed.
- Forced Light/Dark, System switching with an open sheet and appearance persistence were verified. App icons were inspected in both appearances. Baselines and history survived restart. Redeploy confirmation was opened and dismissed.
- Real comparison capture, reveal, side-by-side and expanded inspection were exercised on phone and iPad. Largest Dynamic Type Home reflows metadata without clipping.
- Actual Duo pose and rotation controls produced closed/open/book/tabletop/tent native captures and retained selected-site evidence. Both LCDs were inspected in light/dark, with inner portrait/landscape coverage.
- A fresh independent reviewer inspected 28 native captures, three references and primary UI source. Its token-prompt contrast finding was fixed and independently scored resolved: 6.14:1 light and 6.76:1 dark. A separate fresh documenter saved the durable design tokens.

Physical-device Apple Intelligence latency remains unverified because the paired phone was unreachable. Two accepted simulator briefs took 5.3 and 4.8 seconds using 119/128 input tokens in a 4,096-token context. The Duo 3D mirror was unavailable, so new feature tap flows were exercised on phone/iPad; physical Duo gesture and posture performance are unverified. [Detailed evidence](ui-refresh-2026-10-11.md) records these limits.

## Listing artwork

The user requested a format distinct from Codable. The final 19 posters use flat numbered inspection sheets, compact captions and aligned native app captures. Every poster was exported through the attributed editor's existing browser renderer and carries embedded provenance. There are no invented app states, environment values, another app's captures or substituted device bezels.

| Native canvas | Size | Posters | App Store display set |
| --- | --- | --- | --- |
| Large iPhone | 1320 × 2868 | 5 | APP_IPHONE_67 |
| Standard iPhone | 1206 × 2622 | 5 | APP_IPHONE_61 |
| iPad | 2064 × 2752 | 5 | APP_IPAD_PRO_3GEN_129 |
| Duo inner | 2007 × 2853 | 2 | APP_IPHONE_DUO |
| Duo outer | 1398 × 2034 | 2 | APP_IPHONE_DUO |

All 19 uploaded assets are **COMPLETE**, with source checksums matching the approved files. Smaller compatible devices inherit App Store assets. The focused-slot planner's APP_IPHONE_65 warning is advisory; the supplied large-phone set is accepted and final readiness reports no blocking issues. The two metadata keyword-overlap warnings and API-unverifiable privacy-publication advisory remain nonblocking. The final submit succeeded.

Editable studio, original captures, native trace, format JSON, gallery, approvals and validation live in `artifacts/app-store-1.4.0-39/`. The [artwork ZIP](../artifacts/app-store-1.4.0-39/exports/Taktung-AppStore-1.4.0-39.zip) contains the submitted PNGs. The [gallery](../artifacts/app-store-1.4.0-39/public/gallery/index.html) provides full-size inspection. Start the studio with `node node_modules/next/dist/bin/next dev --webpack --hostname 127.0.0.1 --port 52525` from its directory.

## Receipts

`.asc/qa/` contains final build/archive/export/upload, attached build, metadata, readiness, dry-run and submission receipts. Key files: `review-1.4.0-39-submit.json`, `review-1.4.0-status.json`, `version-1.4.0-after-submission.json`, and `screenshots-1.4.0-checksum-proof.json`. The signed archive and IPA are in `.asc/artifacts/`. Earlier builds 37/38 are superseded and were not submitted.

The original submission is superseded. Monitor [1.5.0](release-1.5.0.md); Waiting for Review confirms submission, not Apple's approval.
