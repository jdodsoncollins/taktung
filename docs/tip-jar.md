# Optional Tip Jar

The 1.8.0 (46) candidate adapts the latest October 21 TabForge implementation from `ScriptKeyboard/App/TipStore.swift` and `TipJarView.swift`, including its scene-aware SwiftUI purchase action. Settings → Tip Jar works independently of Vercel connection and never changes access to app features.

| Tip | Product ID | US base price |
| --- | --- | --- |
| Kind Tip | `com.jcollins.takt.tip.kind` | $0.99 |
| Thoughtful Tip | `com.jcollins.takt.tip.thoughtful` | $1.99 |
| Wonderful Tip | `com.jcollins.takt.tip.wonderful` | $2.99 |
| Incredible Tip | `com.jcollins.takt.tip.incredible` | $3.99 |
| Extraordinary Tip | `com.jcollins.takt.tip.extraordinary` | $4.99 |

All five are repeatable consumables. Prices in the app come only from StoreKit `Product.displayPrice`; the table records configured US base prices, not fallback UI labels. Missing products stay unavailable, and retry, restriction and loading states are explicit. The public catalog IDs are specific to Taktung: Apple rejected reusing TabForge's existing `tip.kind` identifier, so no TabForge product was changed.

## Lifecycle and privacy

The app owns one observable TipStore and starts its idempotent transaction listener at launch. The initiating Tip Jar view supplies `Environment(\.purchase)` so Apple's confirmation has the correct scene context on phone, iPad and Duo. Settings uses the standard modal confirmation-action placement for Done and registers value-based destinations outside the lazy list. The sheet navigation container owns purchase-result alerts so their presenting focus environment remains alive during Back navigation. Buttons lock before awaiting to prevent overlapping checkout requests.

Cancellation is quiet, pending approval is distinct from success, and failures/unverified results never produce thanks. Only verified, purchased, non-revoked transactions for configured consumables are finished. Updates and unfinished transactions are handled after leaving the screen; the bounded in-memory duplicate window prevents double handling. Old or deferred updates are acknowledged quietly.

Taktung has no tip backend, purchase upload, saved purchase history, total, entitlement or Vercel-account linkage. StoreKit owns Apple's transaction records; Taktung keeps at most 128 transaction IDs in memory for duplicate handling. Payments remain in Apple's confirmation UI. Tips do not unlock features, start subscriptions, affect inspection review prompts or change widget/Siri access. The widget extension does not link this purchase service.

The canonical privacy link is https://www.jeremycollins.net/taktung/privacy and the marketing URL is https://www.jeremycollins.net/taktung. The user approved the live policy correction on October 21. Website PR #30 was merged as `4c52535aa142bcbffc4cbb5874e5ba370655371b` and deployed to production as `dpl_715nJfSE6GEVRLggAbdY3qMyDZt8`. The public URL returns 200 and describes optional Apple tips; the old “not monetized” statements are absent. See `docs/tip-jar-privacy-update.md` for the approved wording.

## Test setup and evidence

`Taktung` runs the deterministic domain and purchase-state tests. The isolated `Taktung Tips` scheme and serial `TipJar.xctestplan` select `TaktungTests/TipJar.storekit` for local Apple transactions and native UI tests. The configuration belongs only to test bundles and must never ship in the Release app or widget. Give each StoreKit run exclusive ownership of its simulator and let the previous xcodebuild process finish before starting another.

The first regression passed 156 tests with no failures or skips. The MCP transport timed out at 300 seconds, but the completed xcresult independently reports Passed; no replacement regression run was needed. The native checkout cancellation test passed on the compact phone and its screenshot visibly identifies Xcode's no-charge test environment. A context-free headless test call reached account sign-in; the revised integration test supplies scene context, matching the shipping UI. This initial failed harness is retained and is not counted as a passing transaction test.

Further local purchase/layout evidence and distribution state are recorded in [release-1.8.0-46.md](release-1.8.0-46.md). Local StoreKit tests do not establish the real TestFlight catalog or physical-device purchase behavior. All five products require review with the app's first consumable submission; do not call draft products approved.
