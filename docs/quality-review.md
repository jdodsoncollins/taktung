# Taktung quality assessment

The 1.4.0 follow-up includes the native UI refresh, live checks against five connected projects, 79 full regression tests plus 10 focused history/comparison tests, and a resolved independent visual review. See [the current validation](ui-refresh-2026-10-11.md) and [release record](release-1.4.0.md). The assessment below records the earlier 1.3.0 work.

The reviewed defects are fixed locally and verified. Real visual comparison, persistent history and the Field Log are included in 1.3.0 (36). The earlier 1.2.0 (35) binary is live. See [release evidence](release-1.3.0.md) for the latest results.

## Scope

Reviewed the current SwiftUI app, its API/session boundaries, local evidence storage, adaptive layouts, and tests on `main` at `dde795f6f9579d9b4134d6c48328114148e0e606`. The working tree already contained release and feature changes; no commit, push, or App Store upload was made during this assessment.

Eight local review lenses covered correctness, security, Swift/iOS behavior, testing, project standards, maintainability, reliability, and adversarial cases. Persistence and account switching needed particular attention because the new journal and saved images outlive individual API requests.

## Findings and implementation follow-up

All nine retained findings below are fixed in the working tree. Numbers come from the reconciled review, and severity describes the defect before its fix.

| # | Severity | Problem | Resulting behavior | Fix location |
|---|---|---|---|---|
| 1 | P1 | Failed token replacement could pair a new API client with the old account's journal. | Authenticate and fetch projects before installing the replacement identity; failure keeps the previous client and credentials. | [AppSession.swift](../Taktung/Shell/AppSession.swift) |
| 2 | P1 | Successful account replacement retained the previous account's deployment, diagnoses, and confirmation state. | Clear scoped state before restoring the new account's history; reset navigation on scope changes. | [AppSession.swift](../Taktung/Shell/AppSession.swift) |
| 3 | P2 | Rejected authentication hid local data erasure. | Settings offers disconnect and erasure whenever local account data exists. | [SettingsView.swift](../Taktung/Features/SettingsView.swift) |
| 4 | P2 | A stale BUILDING list summary blocked comparison after detail refreshed to READY. | Detail and Compare use the refreshed deployment when it matches the selected site. | [DeploymentDetailView.swift](../Taktung/Features/DeploymentDetailView.swift) |
| 5 | P2 | Editing the path during baseline lookup could attach captures to the wrong route. | Disable editing during preparation and validate the frozen route before publishing captures. | [VisualComparisonView.swift](../Taktung/Features/VisualComparisonView.swift) |
| 6 | P2 | A failed clear hid persisted history and prevented a retry. | Restore visible records on failure, preserving entries added while clearing. | [AppSession.swift](../Taktung/Shell/AppSession.swift) |
| 7 | P2 | A failed append was lost when a later write succeeded. | Merge the bounded in-memory journal into the next append, deduplicated by ID. | [LocalEvidenceStore.swift](../Taktung/Services/LocalEvidenceStore.swift) |
| 8 | P2 | Automatically chosen teams and explicit Personal selection did not restore consistently. | Persist the actual account/team identity, including an explicit Personal marker. | [AppSession.swift](../Taktung/Shell/AppSession.swift) |
| 9 | P2 | API tests could pass with promote and rollback endpoints swapped. | Each operation checks its exact endpoint, method, identifiers, and team query. | [VercelAPIMappingTests.swift](../TaktungTests/VercelAPIMappingTests.swift) |

Account changes (#1, #2, #3, #8), journal recovery (#6, #7), and comparison state (#4, #5) were handled as separate fix groups. The testing issue (#9) was corrected independently.

## Pre-existing issues corrected

- A delayed deployment-detail action could target the newly selected site's deployment. Detail actions now require the original deployment ID and reject a changed selection. A gated session regression test exercises the site-switch sequence.
- A failed log request returned an empty list, making Errors look clear. Log loading now throws on failure, and Logs/Errors show loading, failure, and Retry separately from a successful empty result.

## Fit and finish

- The reference picker wrapped into the capture button on Duo. Its label and menu now stack vertically; the final inner and outer display checks showed no overlap.
- A late WebKit failure from one thumbnail could fail the next queued capture. Navigation identity checks reject stale callbacks, and a real WebKit lifecycle regression verifies that the next image still renders.
- Comparison state lives above the adaptive layout. Fresh images and the reveal position survived closing and reopening Duo. Earlier native checks also verified side-by-side mode, expanded review, baseline saving, note/search/export flows, and restart persistence.
- The comparison uses real PNG pixels, a reveal control, commit/time provenance, and a saved baseline per site/path. History supports local notes, search, site filters, full details, and text export.

The [final Duo capture](../artifacts/visual-history/comparison-polished-duo.jpg) shows the native expanded review. It uses deterministic demo HTML through the same WebKit rendering pipeline; live sessions load deployment URLs.

## Coverage

- All eight local reviewer roles completed. One independent local validator assessed ten original claims: nine were confirmed; one was correctly classified as pre-existing. The endpoint-test issue was reduced from P1 to P2 because it was a test weakness, rather than a demonstrated production endpoint defect.
- One proposed state-alias cleanup was rejected because it established no material defect or maintenance benefit. No malformed returns, confidence suppressions, or degraded P0/P1 validation remained. No external peer review ran.
- The release suite now contains 67 tests, all passed with zero failures, skips, warnings or errors. It includes the WebKit lifecycle regression, five Field Log domain tests and note retry recovery. The final one-line scroll-inset correction was subsequently built and verified through the native new-entry flow. [Validation receipts](../artifacts/visual-history/validation.md) record both result bundles.
- Domain, API mapping, storage, and session tests cover account/team/demo isolation, credential redaction, route/origin constraints, failed writes, clear retry, stale selection, refreshed state, and connection/navigation races.
- Native smoke checks covered Duo inner/outer displays and iPhone 18 Pro Max. The final Duo pass confirmed disabled controls during capture, fresh rendered differences, folding state preservation, the picker layout, and the expanded sheet.
- Live public deployment comparison and baseline saving passed with the existing reviewer account in the release smoke test. Protected deployment authentication redirects, timeout and cancellation lack exhaustive live/automated coverage.
- VoiceOver navigation still needs a dedicated pass. The largest Dynamic Type size received a Duo cover smoke check; this is not a complete accessibility audit. Simulator smoke checks do not establish accessibility coverage or performance measurements.
- No implementation plan was selected for settlement suppression. The user requests and repository rules supplied the intended behavior.

## Verdict

**Ready with fixes** for 1.3.0. No unresolved confirmed findings remain from this review. The [release record](release-1.3.0.md) distinguishes exercised live capture paths, simulator coverage and remaining accessibility/performance limitations.

**Actionable findings: none.** Review artifacts: `/tmp/taktung-quality-review-20261010/`.
