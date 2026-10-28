# Taktung 1.9.0 (48)

## Scope and authorization

On October 27 the user reported that Apple Intelligence search did not work. The Search tab was gated on the model but never called it. In the project thread that evening the user asked for:

- Search on every device, with a magnifying-glass tab icon and an "Apple Intelligence used for deeper searching" badge and switch;
- the on-device context features;
- a thorough regression test;
- "Post to TestFlight when done".

This release is an internal TestFlight build only. Nothing was submitted for external beta or App Review, and the 1.8.1 (47) submission was not touched.

## Features

- **Search on every device:** plain-language deployment requests become filters (state, target, branch, SHA, time, count) for one read-only `GET /v7/deployments`, and the device re-checks every result. Related-word commit matching runs when exact text finds nothing. Apple Intelligence reads only phrasing the rules can't place, and only while the Search page's switch is on. See [Apple Intelligence](apple-intelligence.md#search).
- **Home, "Since you last looked":** what changed on the selected site since it was last on screen.
- **Field Log:** plain-language search (it follows the same switch) and "Summarize the last 7 days".
- **Failed builds:** key redacted log lines on every device, plus a grounded one-sentence on-device explanation.
- **Spotlight:** opt-in recent deployments and Field Log notes, off by default. See [on-device context](on-device-context.md).
- **Model input policy:** build-log and Field Log text reach the on-device model only as bounded, redacted excerpts. Runtime logs and environment values never do.

## Regression fixes before upload

The regression pass found four issues, all fixed and rechecked before archiving:

1. In Demo, the "Since you last looked" card was missing at launch.
2. In Demo, returning to a site reported a rebuilt deployment as new.
3. The Tip Jar intro was clipped at the leading edge. This predated 1.9.
4. At accessibility sizes, "Summarize the last 7 days" was truncated and its icon overlapped the text.

## Verification

Local receipts are in `.asc/qa/release-1.9.0/`. Screenshots are in `artifacts/regression-1.9.0/`. Neither is tracked.

- **Unit tests:** `TaktungTests` 214 passed, 0 failed, 0 skipped at 5ad39fd, on the iPhone 17 simulator (iOS 27.2).
- **Tip Jar plan:** 6 of 6 passed (`TipStoreKitTests` plus five `TipJarUITests`), on the iPhone Air simulator, `Taktung Tips` scheme, parallel testing off.
  - An earlier attempt with the test plan and parallel testing stopped at a system Apple Account sign-in sheet. Nothing was entered, and that run is not counted.
- **Builds:** the Demo scheme, the widget extension and a Release build succeeded with no new warnings. The Release archive at c0e4dda succeeded with no warnings.
- **Demo regression:** iPhone 18 Pro simulator (iOS 27.2), at Large and AX3 text, in Light and Dark. Items that passed:
  - Settings: disconnected state, appearance persistence, Spotlight section, Tip Jar prices.
  - Home: checks, failed-build key lines, the visit card at launch and its quiet return line.
  - Deploys: filters, search, build-log search, errors-only and copy. Action confirmations were dismissed, never confirmed.
  - Field Log: plain-language search with the switch off, export, and the 7-day card and its links.
  - Search: badge and switch, including persistence; recent searches, clear and New search; related words, environment and no-match.
  - Visual comparison: capture, reveal, side-by-side and baseline.
  - Background and return.
  - Widgets: small, medium and large, and the Edit Widget project filter.
  - Shortcuts app: Open Deployments, and Site Health for a named project. Get Deployment Status correctly asks for a live connection in Demo.
  - The `takt://deploys` route.
- **Not verified:**
  - iPad landscape: no simulator access was granted during the pass.
  - Every live Vercel path, because no live session was available on the test Mac: Search results, Analytics, runtime start and stop, domains, checks, cron, flags, Deploy Status, and Spotlight indexing and opening.
  - Real Apple Intelligence output for search, build explanations and summaries. Demo never calls the model, and tests inject generators.
  - Physical devices.

## Artifact

`Taktung` scheme, Release, archived at c0e4dda and exported with `.asc/ExportOptions-1.8.0-46.plist`.

`.asc/artifacts/Taktung-1.9.0-48.ipa` is 5,761,395 bytes, SHA-256 `44b7fd4cb0820ddc5f1cd8b02f78dc97ce80ff5bb05945b03cee3fe97adec116`. The audit found:

- Host and widget both report 1.9.0 (48) with minimum iOS 27.0.
- Strict signatures are valid, debugging is disabled, and both use the existing device-only Keychain group.
- No `.storekit`, StoreKitTest or test-bundle resources are present.
- The canonical privacy URL is embedded.
- No credential-length Vercel token appears in any IPA file, and the Debug-only `TAKT_UI_TOKEN` bootstrap is absent from the Release binary.

## Distribution — October 28

- **Build:** `41458abb-bc66-4037-87c7-02d7e8a19137`, **48**, **VALID**, encryption exempt. Uploaded 2026-10-28 01:54 UTC.
- **Internal TestFlight:** **IN_BETA_TESTING** through `Team (Expo)` (`969268ca-e12f-47b5-aba7-79659a1b9f28`) all-builds access.
- **External:** READY_FOR_BETA_SUBMISSION. Nothing was submitted for external beta review.
- **What to Test (en-US):**

  > Search works on every iPhone now. Try plain requests like “failed preview builds yesterday” or “last successful deploy on main”; results come live from Vercel. On phones with Apple Intelligence, a switch on the Search page lets it read unusual phrasing.
  > Home shows what changed since you last looked.
  > Field Log: search in your own words, and summarize the last 7 days.
  > Failed builds show their key log lines, with a one-sentence explanation where Apple Intelligence is available.
  > Settings → Spotlight (off by default) adds recent deployments and Field Log notes to Spotlight.

- **1.8.1 (47):** observed read-only at upload time as **READY_FOR_DISTRIBUTION** (submission `c2f2c702-13e3-4e2d-b9ce-008b781d9164` COMPLETE). This release did not change it.

Monitor without changing anything:

```sh
asc builds info --build-id 41458abb-bc66-4037-87c7-02d7e8a19137
asc builds groups list --build-id 41458abb-bc66-4037-87c7-02d7e8a19137
```

## App Review submission — October 28

The user approved submission in the project thread ("Submit"). That covered submitting 1.9.0 (48) for review with automatic release after approval, the drafted store text and the review-notes change.

- **Version:** `baf7e0e9-8706-4c46-a994-aba94b180105`, **1.9.0**, **WAITING_FOR_REVIEW**, build 48 (`41458abb-bc66-4037-87c7-02d7e8a19137`) attached.
- **Review submission:** `c62e8c60-679e-4e89-9955-f3e72d6e1c28`, **WAITING_FOR_REVIEW**, submitted **2026-10-28 02:43:21 UTC** with one item, the app version (READY_FOR_REVIEW).
- **Release policy:** **AFTER_APPROVAL**, no phased release, matching 1.8.1.
- **Metadata:** staged from `metadata/version/1.9.0/en-US.json`. The field-level plan changed only the description, promotional text and What's New. Keywords, URLs, app information, pricing, tips and media were not changed.
- **Inherited:** all 31 screenshots and both App Previews (COMPLETE), age rating 4+ (Brazil L), copyright and review contact.
- **Review notes:** updated for this version. The existing block is kept, the stale sentence about tip products being in their first review is removed, and a paragraph explains the 1.9.0 features: Search on every device and its Apple Intelligence switch, "Since you last looked", Field Log search and summary, failed-build key lines, and Spotlight being off by default. The reviewer access instructions are unchanged and are not reproduced here.
- **Validation:** strict validation reported 0 errors and 0 warnings, plus the standard App Privacy publish-state advisory. The submit dry run confirmed build 48 was already attached and no other submission was open.
- **What's New (en-US):**

  > Search now works on every iPhone and iPad. Ask in plain words, like “failed preview builds yesterday” or “last successful deploy on main”, and Taktung asks Vercel directly.
  >
  > - Home shows what changed since you last looked.
  > - Search the Field Log in your own words and summarize the last 7 days.
  > - Failed builds show their key log lines.
  > - Optionally add recent deployments and Field Log notes to Spotlight.
  >
  > With Apple Intelligence, Taktung can also read unusual phrasing and explain a failed build in one sentence, on your device.

- 1.8.1 (47) remains READY_FOR_DISTRIBUTION and was not changed.

Monitor without changing the submission:

```sh
asc review submissions-get --id c62e8c60-679e-4e89-9955-f3e72d6e1c28 --include items
```
