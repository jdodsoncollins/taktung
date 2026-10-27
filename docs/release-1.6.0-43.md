# Taktung 1.6.0 (43)

App Store Connect confirmed **1.6.0 live (READY_FOR_SALE / READY_FOR_DISTRIBUTION) on October 20**. The submission details below preserve the October 17 receipt.

Released to internal TestFlight on 2026-10-17. The user then separately authorized an App Store release and refreshed imagery. **1.6.0 (43) was WAITING_FOR_REVIEW at submission**, submitted October 17 at 09:25 America/Los_Angeles, with automatic release after approval. It was not yet public at that point. App Store Connect confirmed 1.5 live before staging this release; [its record](release-1.5.0-42.md) preserves the earlier submission.

## Included

- A Home tool directory available without Apple Intelligence: Vercel activity, domain ownership, deployment checks, cron schedules and feature flag names.
- Deployment text search and independent Production/Preview plus state filtering.
- Searchable newest-500 build-log window with timestamps, error-like filtering, refresh and redacted copy/share.
- A bounded runtime stream for a selected deployment, with search, error filtering and Stop/Start.
- Fresh domain ownership and runtime sample counts in compact site-health briefs, with scope/TTL validation and qualification-aware model acceptance.
- Native proportional page titles, flat tool/evidence rows, opaque neutral backgrounds and existing teal accents.
- All existing small/medium/large widgets, Siri/Shortcuts, comparison/history, adaptive workspaces, appearance settings and centered layered icon C.

The [inspection architecture](project-inspection.md) records API contracts, actual semantics and verification limits. The TestFlight What to Test text is preserved in `.asc/qa/release-1.6.0/what-to-test.txt`. The later App Store step preserves the requested notes and widget paragraph, adds one inspection-tools paragraph, and updates the description with the completed tools/log features. Canonical and remote 1.6 metadata match exactly.

## Build and distribution

| Field | Verified value |
| --- | --- |
| App | `6805738660`, `com.jcollins.takt` |
| Version / build | `1.6.0` / `43`, matching host and widget extension |
| Build ID | `d7afa461-d0cd-4deb-b959-7c63600eb80b` |
| Apple processing | `VALID` |
| Internal TestFlight | `IN_BETA_TESTING` |
| App Store version ID | `dde6f669-ec9c-46cc-881b-f59bb1670843` |
| App Store state | `WAITING_FOR_REVIEW` |
| Submission ID | `1ea3163c-1fe0-41a3-be7f-373ba4b2a460` |
| Submitted | `2026-10-17T16:25:15.7Z` |
| Release type | `AFTER_APPROVAL` |
| Existing internal group | `Team (Expo)`, `969268ca-e12f-47b5-aba7-79659a1b9f28` |
| Group verification | `complete=true`, `membership=explicit-and-all-builds`, `hasAccessToAllBuilds=true` |
| What to Test | en-US localization `3e349462-a8d5-4d44-ac72-7ea64c38260e`, remotely verified |
| Minimum OS | iOS 27.0, host and widget |
| Build expiration | 2027-01-15 07:39:11 America/Los_Angeles |

`asc` archive/export succeeded using Xcode 27.1 and the existing distribution identity/profiles. Both exported signatures pass strict verification, have `get-task-allow=false`, and retain the existing device-only Keychain group. Demo mode is off. The test credential is absent from the exported app. The IPA is 4,641,968 bytes.

The upload dry run succeeded, followed by upload/processing and saved test notes. Apple had already made the processed build available through the internal group's all-build access. A redundant manual assignment attempt returned HTTP 422 because this internal group cannot be manually added to a build; the subsequent build-group lookup verified existing explicit/all-build membership. No tester invitation or external beta-review submission was needed.

## Quality evidence

- Final unit regression: **132 passed, zero failures/skips**, `.asc/qa/release-1.6.0/regression-verified.xcresult`.
- Real connected-project UI/API checks: matching production metadata, 60 chronological build-log lines, five `cache` search matches, copy verification, three verified domains, expected empty checks/crons/flags and real Vercel activity.
- Forced Light and Dark, phone portrait and landscape, and the largest accessibility text size were inspected. Runtime Stop responded at that accessibility size.
- The original live Duo check launched and navigated the new tools directory on the outer display. The later App Store capture pass separately verified Demo Home in Light/Dark on both the closed portrait outer display and expanded landscape inner display, using Device Hub's real pose controls. The expanded captures show the native two-column workspace. No physical-device verification is claimed.
- A live runtime connection remained quiet during the observation; framing/redaction were tested through deterministic transport fixtures. No production fault was injected, and no physical Apple Intelligence performance claim is made.

An intermediate regression exposed a generated brief dropping the runtime sample qualifier. The final build rejects that response and preserves the qualified heuristic; a dedicated regression covers it. The deterministic session tests also explicitly disable model availability so they cannot depend on simulator generation.

Receipts, safe live contract summaries and UI captures are in `.asc/qa/release-1.6.0/`. Archive and IPA: `.asc/artifacts/Taktung-1.6.0-43.xcarchive` and `.asc/artifacts/Taktung-1.6.0-43.ipa`.

## App Store release and imagery

The existing VALID build 43 was attached to the new 1.6 version; this imagery/metadata pass did not change the native app or require another binary. Final strict readiness: **zero errors, zero warnings, zero blockers**. The API's informational App Privacy publication advisory remains unverifiable through its public interface. An existing published Data Not Collected label was observed on Apple's public listing; collection behavior is unchanged. Apple's final submission accepted the release without a privacy blocker.

The [image package](app-store-imagery.md) contains 28 browser exports: eight each for large/standard iPhone and iPad, plus two expanded landscape Duo and two closed portrait Duo images. Existing seven headlines/captions remain word-for-word, with larger weight-700 headlines, primary-color captions and measured Apple product bezels. Sheet 08 adds Project tools. Genuine small/medium and large widgets remain included. Ten new native Demo source files supply thirteen placements; fifteen unchanged placements retain verified 41/42 provenance. Captures were not retouched.

All **28 remote assets are COMPLETE**. Dimensions, order and MD5 source checksums match the reviewed local exports in all four display sets. The planner's generic focused 6.5-inch advisory is covered by the accepted large iPhone set, as in 1.5; final readiness has no screenshot warnings. Full-size local Duo artwork and camera clearance were inspected. App Store Connect's account preview required a fresh browser login and was not inspected; this does not imply an account-preview verification.

The original [App Store screenshot skill](https://github.com/ParthJadhav/app-store-screenshots/blob/5386f227360bddb06c8beaff920a1a34c9f01932/skills/app-store-screenshots/SKILL.md), creator @parthjadhav8, supplied the restored Apple bezel implementation. Editable studio, source hashes, licensing, review gallery and ZIP: `artifacts/app-store-1.6.0-43/`. Gallery runs at <http://127.0.0.1:52529/gallery/index.html>.

Review contact and existing reviewer access were preserved; notes explain the new tools and runtime sample limits. Metadata, build attachment, image proofs, strict validation, dry-run plan, successful submission and subsequent WAITING_FOR_REVIEW/AFTER_APPROVAL reads are saved in `.asc/qa/app-store-1.6.0-43/`. Raw review credentials are excluded from those receipts. No second review request was created.
