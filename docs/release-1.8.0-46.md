# Taktung 1.8.0 (46)

## Scope and authorization

On October 21 the user requested a new minor release with TabForge’s latest Tip Jar implementation, TabForge and Paper & Grain in Other Apps, updated product/privacy URLs, and App Review submission once quality checks passed. The user separately approved publishing the factual Tip Jar privacy policy update.

This release retains the unreleased 1.7 Web Analytics work, all widgets and shortcuts, comparison, Field Log, project inspection and icon C. It supersedes the unsubmitted 1.7.1 (45) draft, which superseded the withdrawn 1.7.0 (44) submission. Those earlier review records remain historical.

## Native implementation

- Settings → Tip Jar offers five optional, repeatable consumables following the latest TabForge scene-aware StoreKit implementation. Localized prices come from Apple; tips never unlock features or start subscriptions.
- Verified transaction finishing, pending approval, cancellation, restrictions and retry are explicit. There is no purchase backend, uploaded transaction history or Vercel-account linkage. Deduplication is bounded to 128 in-memory transaction IDs.
- Other Apps includes Codable, TabForge and Paper & Grain with published icons, detail pages and App Store links.
- AppConfig and canonical metadata point to the new /taktung product and /taktung/privacy pages.
- iPad regression testing found a UIKit focus crash when returning from a scrolled Settings destination, including after the thank-you alert. The repaired Settings uses the standard modal confirmation-action placement for Done; pinned toolbar placement was removed. It also registers value-based destinations outside lazy rows and keeps purchase-result alerts on the stable sheet navigation container. The exact two failing cases then passed on iPad: dark Tip Jar/Other Apps navigation and two completed tips followed immediately by Back. Final multi-device verification is recorded below.

## Privacy publication

Approved website change: [PR #30](https://github.com/jdodsoncollins/JeremyCollinsDotNet/pull/30), merged as `4c52535aa142bcbffc4cbb5874e5ba370655371b`. The policy was tested (17 tests and successful production build) in an isolated checkout based on the current production commit. Deployment `dpl_715nJfSE6GEVRLggAbdY3qMyDZt8` is READY and serves the public domain. The live [privacy policy](https://www.jeremycollins.net/taktung/privacy) returns 200, explains optional Apple tips and contains neither old monetization claim.

## Catalog

| Tip | Product ID | Parent ID | Version ID | US base price |
| --- | --- | --- | --- | --- |
| Kind | com.jcollins.takt.tip.kind | 6825399879 | 0bcbda76-2f0a-4141-a5e3-a04c0f2a4197 | $0.99 |
| Thoughtful | com.jcollins.takt.tip.thoughtful | 6825400267 | 4219b90d-f351-4217-8bd5-89a641bcfc51 | $1.99 |
| Wonderful | com.jcollins.takt.tip.wonderful | 6825400214 | dc2c2d6f-ad7f-4f25-92d0-0dd58727912a | $2.99 |
| Incredible | com.jcollins.takt.tip.incredible | 6825399992 | c3d2bbc4-7814-44fa-8de7-e7205e04c1ee | $3.99 |
| Extraordinary | com.jcollins.takt.tip.extraordinary | 6825400223 | ad3d8348-a28a-4149-adae-2d98835c40e1 | $4.99 |

All five match the app’s 175 existing sales territories. Future territory availability is disabled. Apple rejected reusing TabForge’s identifiers; Taktung uses its own namespaced catalog, and no TabForge product was changed. Correct review screenshots are COMPLETE; reference names, version localizations, review instructions and prices are configured. Before submission all five parents were READY_TO_SUBMIT with no blocking validation issues.

## Listing media

The inherited 31 number-free, framed native screenshots are COMPLETE. Copy and approved imagery remain appropriate for this optional Settings addition; no screenshot re-export was needed. Two 18-second App Previews are COMPLETE in the editable version: iPhone (886×1920, `82800019-5a75-84a4-810c-48c3ea62d5b1`) and iPad (1200×1600, `d8c00019-5a75-84a4-813e-54e60285f54c`). They become public only after the new App Store release is approved.

## Verification and distribution

Candidate verification is in `.asc/qa/release-1.8.0/`. The initial full regression passed 156 tests with no failures or skips. Native local StoreKit tests cover repeated tips and pending approval; phone cancellation, largest text and landscape passed. Duo cancellation, largest text and repeated purchases/back passed. Initial iPad failures and the corrected verification are retained separately; failed runs are not counted as passing evidence. Native tests are local Xcode no-charge transactions, not physical-device or production-catalog purchase proof.

Final device flows passed on all three devices: iPad Pro 13-inch (M5), iOS 27.0 (2/2); iPhone 17 Pro, iOS 27.0 (2/2); iPhone Duo, iOS 27.1 (2/2). The consolidated run contains four passes on phone/iPad and two Duo locator failures; the corrected Duo-only run passed both. The native Duo Back button has an identifier without the Settings title label, so only the test locator changed for that rerun. The signed binary was unchanged. The final gate is `final-quality-gate.json`; device results are `tips-final-devices.xcresult` and `tips-final-duo.xcresult`. iPad also passed the exact repaired cases independently before the final multi-device run.

The shipping artifact is `.asc/artifacts/Taktung-1.8.0-46-final.ipa` (5,115,144 bytes), exported from `Taktung-1.8.0-46-final.xcarchive`. SHA-256: `ed06feb274cd78c2593eda3783f7caf4cfd4d9695699e9d05dab44bfa1cebbce`. Host and widget both report 1.8.0 (46), minimum iOS 27.0, valid strict signatures, debugging disabled and the existing device-only Keychain group. Local `.storekit`, StoreKitTest and test-bundle resources are absent. The canonical privacy URL is embedded; no credential-length Vercel token match is present. The older non-final archive/IPA predates the iPad repair and was not uploaded.

## Accepted submission — October 21

- App: `6805738660` / `com.jcollins.takt`.
- App Store version: `e43d9961-f4ff-4cf4-a89e-b0a02463fa63`, **1.8.0**, **WAITING_FOR_REVIEW**.
- Processed build: `a6c6129f-23d8-48cb-896e-023a77e3b0ae`, **46**, **VALID**.
- Review submission: `63756a2e-3e9f-4f5c-9103-24aa69215ae1`, **WAITING_FOR_REVIEW**, accepted **2026-10-21 16:25:25.62 UTC** (09:25 Pacific).
- Exactly six intended review resources: the app version above plus the five product version IDs in the catalog table. Apple confirmed every tip parent **WAITING_FOR_REVIEW**. Individual submission items remain READY_FOR_REVIEW until review starts.
- Release policy: **AFTER_APPROVAL**. This submission is not yet a public release.
- Internal TestFlight: **IN_BETA_TESTING**, accessible to existing `Team (Expo)` group `969268ca-e12f-47b5-aba7-79659a1b9f28` through its all-builds access. No duplicate tester-group mutation was needed. What to Test notes are applied.

Staging and review dry runs matched the intended version/build. Canonical metadata was already in sync. Before assembly, app validation reported zero errors and five expected READY_TO_SUBMIT warnings for these first consumables; strict mode promotes those warnings to blockers. They were resolved by submitting the five prepared products with the app in one lower-level multi-item submission, rather than submitting the app alone. The API-only privacy-publish advisory was informational; the existing no-developer-collection behavior is unchanged by device-local StoreKit handling.

Receipts: `stage-applied.json`, `readiness-app.json`, `review-resource-proof.json`, `review-submitted-verified.json`, `version-release-policy.json`, `iaps-submitted.json`, `testflight-beta-detail.json`, `testflight-groups.json`, `testflight-notes-applied.json` and `privacy-published-proof.json`. Reviewer instructions cover Tip Jar and preserve existing review access without exposing credentials in these release receipts.

Monitor without changing the submission:

```sh
asc review submissions-get --id 63756a2e-3e9f-4f5c-9103-24aa69215ae1 --include items
```

Canonical release notes and description: `metadata/version/1.8.0/en-US.json`. They include optional tips, Web Analytics, the Other Apps refresh, the previously requested rendering/Duo/bug-fix/UI notes and widget support. The marketing/privacy URLs have been updated in App Store Connect and AppConfig; the privacy policy is independently published.

