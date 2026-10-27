# Taktung 1.7.1 (45) — preview release draft

App Store Connect verified `PREPARE_FOR_SUBMISSION` on October 21, 2026. The user requested a point release with app-preview videos. No review submission or public release was performed.

The earlier 1.7.0 submission had already been withdrawn (`DEVELOPER_REJECTED`; its review submission was complete with no active items). Apple permits only one editable iOS version, so the existing editable version was renumbered to 1.7.1. Its metadata and all 31 screenshots were preserved. A new matching build replaces build 44.

- App: `6805738660`, `com.jcollins.takt`.
- Version ID: `e43d9961-f4ff-4cf4-a89e-b0a02463fa63`; English localization `ac652f03-3f6a-4855-8bc7-1200b0d74675`.
- Attached build: `fde779cb-0579-47f1-8b43-b430b17bc532`, marketing version 1.7.1, build 45, Apple processing `VALID`.
- Both 18-second iPhone and iPad App Store previews report `COMPLETE`. The phone cut shows production state, failed deployments and native log filtering. The iPad cut shows adding, saving and reopening a local Field Log note.
- Captures use isolated `-TAKT_DEMO_MODE` fixtures. No live credentials or account records were captured. Store previews show app screens directly; the website compositions additionally use attributed device frames, zooms and native Duo opening/reveal footage.
- Existing unreleased Analytics/Other Apps release notes are retained, with one sentence about the previews. Canonical metadata is `metadata/version/1.7.1/en-US.json`.
- Strict readiness reports zero errors, zero warnings and zero blockers. App Privacy publication remains an informational API limitation; no fresh privacy-panel check is claimed.

Release archive and export succeeded with the existing login-keychain distribution certificate and existing host/widget profiles. Host and widget both report 1.7.1 (45), iOS 27 minimum, and no Demo flag. Deep strict signature verification passed. IPA SHA-256: `ac8fe5290fb56b9042e2197bb815accd626c4dae453b337d3db69f578a8275b9` (5,011,721 bytes).

Receipts: `.asc/preview-release-*`; local archive and IPA: `.asc/artifacts/Taktung-1.7.1-45.*`. Earlier 1.7 runtime regression evidence remains in [the build 44 record](release-1.7.0-44.md); no additional runtime changes or new regression-suite claim is made here. Video sources and delivery receipts are retained in the separate ScriptKeyboard `artifacts/codable-taktung-overviews/` workspace.

Preserve this draft and its build attachment. Website publication and media preparation do not authorize resuming the withdrawn review.


## Superseded October 21

This unsubmitted draft was renumbered and replaced by the separately authorized [1.8.0 (46) release](release-1.8.0-46.md), including optional tips. The new six-item submission is Waiting for Review; build 45 was not submitted again.
