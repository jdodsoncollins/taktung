# Taktung 1.8.1 (47)

## Scope and authorization

On October 27 the user asked to verify the Web Analytics fix in the Simulator, publish it to TestFlight, and then submit 1.8.1 (47) to App Review as a bug fix release. Each step was separately approved.

## Fix

- Vercel's `visits/aggregate` endpoint reads `by` as a plain dimension name. A live request with `by=["day"]` returned HTTP 400 (`by` items must be one of the allowed dimensions); `by=day` returned HTTP 200 with daily buckets. `WebAnalyticsClient` now sends `by=day` (and `requestPath` and other dimensions the same way).
- Vercel's error message is surfaced, and `InspectionFailure` explains 400, 5xx and unexpected responses instead of describing them as connection problems.

## Verification

- Unit tests: 154 passed, 0 failed, 0 skipped on an iPhone 17e simulator (iOS 27.2), including all eight `WebAnalyticsTests`.
- Simulator, Debug `Taktung` scheme, live token for the `jeremy-collins-dot-net` project, www.jeremycollins.net → Project tools → Analytics:
  - Last 7 days (Oct 20 – Oct 26, UTC): 105 visitors, 249 page views. The Pages breakdown sums to 249.
  - Last 30 days (Sep 27 – Oct 26, UTC): 315 visitors, 601 page views. The Pages breakdown sums to 601.
  - Both match `visits/count` for the same completed UTC days with an exclusive next-midnight bound.
- These are simulator measurements, not physical-device verification.

## Artifact

`Taktung` scheme, Release, archived and exported with `.asc/ExportOptions-1.8.0-46.plist` (existing Apple Distribution identity and 1.7 App Store profiles, valid until 2027-10-10). `.asc/artifacts/Taktung-1.8.1-47.ipa` is 5,115,889 bytes, SHA-256 `dbbc3afb956e50e216984435f218c384c6b07bef059b2504fa50f87be94d41f1`. Host and widget both report 1.8.1 (47), minimum iOS 27.0, valid strict signatures, debugging disabled and the existing device-only Keychain group. Local `.storekit`, StoreKitTest and test-bundle resources are absent. The canonical privacy URL is embedded; no credential-length Vercel token appears anywhere in the IPA, and the Debug-only token bootstrap is absent from the Release binary.

## Distribution

- The first upload attempt returned HTTP 500 from App Store Connect while creating the upload record. Apple reported all services operational and no partial record existed; the identical retry succeeded.
- Build `7983288b-1f9b-470e-9dd5-5d8ce0d27843`, **47**, **VALID**, encryption exempt.
- Internal TestFlight: **IN_BETA_TESTING** through `Team (Expo)` (`969268ca-e12f-47b5-aba7-79659a1b9f28`) all-builds access. External state is READY_FOR_BETA_SUBMISSION; nothing was submitted for external beta review. What to Test notes were not set.

## Submission — October 27

- App Store version `5c685038-8217-4c83-8b9a-c54c4aa6504f`, **1.8.1**, **WAITING_FOR_REVIEW**, build 47 attached.
- Review submission `c2f2c702-13e3-4e2d-b9ce-008b781d9164`, **WAITING_FOR_REVIEW**, submitted **2026-10-27 15:18:57 UTC** with one item, the app version.
- Release policy: **AFTER_APPROVAL**, no phased release, matching 1.8.0.
- Description, keywords, marketing/support URLs and promotional text match live 1.8.0 exactly. All 31 screenshots and both App Previews were inherited COMPLETE; review details are identical to 1.8.0. Strict validation reported 0 errors and 0 warnings, with the standard App Privacy publish-state advisory.
- What's New (en-US): "Bug fixes. Analytics now loads visitors, page views and breakdowns for your sites, and errors from Vercel now explain what went wrong instead of blaming your connection."

Canonical metadata: `metadata/version/1.8.1/en-US.json`. Receipts are local in `.asc/qa/release-1.8.1/` and are not tracked because App Store evidence can include review contact details.

Monitor without changing the submission:

```sh
asc review submissions-get --id c2f2c702-13e3-4e2d-b9ce-008b781d9164 --include items
```
