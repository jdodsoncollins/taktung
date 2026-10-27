# App Store imagery — Taktung

Reference approach: task `01a11869-dfb7-7e90-8175-12f6317829d4` (“Find App Store and iOS skills”). This app has its own editor project, genuine simulator captures, and exports. Other apps’ captures are excluded.

## Submitted: 1.7.0 (44)

The October 20 request adds Analytics and explicitly removes sequence numbers from all listing artwork. `artifacts/app-store-1.7.0-44/` contains **31 validated browser exports**: nine each for large/standard iPhone and iPad, plus two expanded-landscape Duo and two closed-portrait Duo images. All 31 sequence-number overlays were removed through the editor UI. Existing headlines/captions are preserved; the new Analytics sheet reads “Know your traffic.” Small/medium and large widgets remain included.

The previous attributed editor, measured Apple frames, large weight-700 headlines, primary-color captions and neutral/teal palette remain. No Codable layouts are reused. All source pixels and aspect ratios are preserved. Five fresh build44 native Demo sources supply six placements: Analytics on both phones and iPad, plus Project tools on iPad and a compact-phone source reused across the two same-aspect phone canvases. The other 25 placements retain verified build41/42/43 provenance. `capture-trace.json` records actual source origins.

All 31 final images were checked on the contact sheet, with full-size phone/tablet Analytics and Duo checks. An initial standard-phone export rendered blank screens; it was replaced after the sources visibly loaded. Only corrected populated exports were approved. Browser **Export bundle** produced every final poster. Packaging verifies RGB/dimensions and embeds provenance without changing decoded pixels. Review manifests, approvals, hashes, gallery and ZIP remain editable in the studio. All 31 remote assets are COMPLETE and match reviewed local MD5 checksums, dimensions and order. The release is WAITING_FOR_REVIEW with automatic release after approval; [the release record](release-1.7.0-44.md) preserves the receipts.

Editor/gallery: <http://127.0.0.1:52530/gallery/index.html>. The [original App Store screenshot skill](https://github.com/ParthJadhav/app-store-screenshots/blob/5386f227360bddb06c8beaff920a1a34c9f01932/skills/app-store-screenshots/SKILL.md), creator @parthjadhav8, supplied the MIT studio and Apple bezel implementation. Sources/licensing are in `PROVENANCE.md`.

## Submitted: 1.6.0 (43)

The October 17 request authorizes the App Store release and a refreshed listing. `artifacts/app-store-1.6.0-43/` contains **28 validated browser exports**: eight each for large/standard iPhone and iPad, plus two each for expanded Duo landscape and closed Duo portrait. The seven existing headlines and outcome captions are preserved word-for-word, with line breaks adjusted. Sheet 08 adds Project tools. Small/medium and large widgets remain sheets 03 and 04.

Headlines use weight 700 and are 1.69–1.93 times their prior font size. Captions are larger and use primary text colors: 14.20:1 contrast on the light ground and 16.84:1 on dark. Teal labels/numbers measure 5.67:1 light and 10.87:1 dark. All sheets were checked at thumbnail size; full-size checks include app, widget and Duo images. Device frames stay fully inside the canvas. Duo's camera covers only the empty status rail; the expanded inner images show the real two-column workspace.

The attributed [App Store screenshot skill](https://github.com/ParthJadhav/app-store-screenshots/blob/5386f227360bddb06c8beaff920a1a34c9f01932/skills/app-store-screenshots/SKILL.md) supplied its Apple bezel renderer, frame assets and cutout measurement code. The prior editable studio is preserved; only its frame presentation and copy sizing changed. Apple bezels are measured from their actual transparent cutouts and used solely for Apple app mock-ups. `PROVENANCE.md` records licensing and creator @parthjadhav8.

Ten fresh local43 native Demo source files supply thirteen placements. Fifteen unchanged placements retain verified build41/42 widget, comparison, Field Log and Settings sources. Source pixels and aspect ratios remain unchanged. Forced Dark sources were captured through the app's actual Settings control after a simulator preference-write attempt did not change the appearance. The standard phone deck reuses same-aspect large-phone Home/tools captures; its other captures remain native compact-phone sources. No live credentials or environment values appear.

The loopback editor/gallery runs at <http://127.0.0.1:52529/gallery/index.html>. Export uses the browser renderer; packaging only verifies RGB pixels/dimensions, embeds provenance and creates the gallery/ZIP. `capture-trace.json`, `export-validation.json` and `.asc/qa/app-store-1.6.0-43/` preserve reproducible evidence. All 28 remote assets are COMPLETE and match reviewed local dimensions, order and MD5 source checksums. The version is WAITING_FOR_REVIEW with automatic release after approval. [Release state](release-1.6.0-43.md) records the accepted submission and subsequent status read.

## Released: 1.5.0 (42)

`artifacts/app-store-1.5.0-42/` contains **25 validated browser exports**: seven sheets each for large/standard iPhone and iPad, plus two each for Duo inner/outer. New sheet 03 shows small/medium widgets; sheet 04 shows the large recent-deployment activity widget. Nine widget/Settings source placements are genuine local42 native Demo captures; sixteen unchanged feature captures retain their original provenance. The compact iPhone source is reused on both phone canvases with its aspect preserved.

The flat numbered inspection sheets, compact deploy-focused captions and neutral/teal palette stay distinct from Codable’s promo composition. Source traces, dimensions, checksums, contact sheet, attributed editor, preview gallery and ZIP are preserved in this directory. All 25 remote assets were COMPLETE, with dimensions, order and checksums verified against approved exports. App Store Connect verified 1.5.0 as READY_FOR_DISTRIBUTION / READY_FOR_SALE on October 17 before 1.6 was staged. See [widget verification](widgets.md) and [the build42 release record](release-1.5.0-42.md).

## Withdrawn release: 1.5.0 (41)

`artifacts/app-store-1.5.0-41/` contains nineteen freshly browser-exported flat numbered inspection sheets. Three icon-bearing listing sources show the centered selected C, derived from verified native iPhone and iPad Settings captures. The genuine compact phone source is used on both phone canvases with its aspect preserved. Sixteen unchanged feature captures remain representative. All 19 remote assets were verified COMPLETE against approved local checksums. Build 41's review request was withdrawn on October 12, 2026 before configurable widgets were added in build 42. Its editable project, source trace, approvals, gallery and ZIP are retained. Build 42's refreshed Settings and genuine widget sheets replace this remote set as described above. See [historical release evidence](release-1.5.0.md) and [widgets](widgets.md).

## Superseded release: 1.5.0 (40)

Its exact pending submission was withdrawn and verified COMPLETE before build41 was attached. [Original release record](release-1.5.0-40.md) is retained.

`artifacts/app-store-1.5.0-40/` contains nineteen freshly browser-exported posters in the flat numbered inspection-sheet format. Three native Settings sources were refreshed to show selected C; sixteen unchanged feature captures remain representative. All nineteen remote assets are COMPLETE and match approved local checksums. Coverage remains large/standard iPhone, iPad and both Duo displays, with smaller compatible devices inheriting artwork. The editable JSON, provenance, native source trace, approvals, gallery and ZIP are retained. See [1.5.0 release evidence](release-1.5.0.md).

## Superseded release: 1.4.0 (39)

The original flat numbered inspection-sheet format and native captures remain in `artifacts/app-store-1.4.0-39/`. Its pending submission was replaced by 1.5.0 at the user's request. [Original release evidence](release-1.4.0.md) is retained.

## Previous release: 1.3.0 (36)

The refreshed artwork is in `artifacts/app-store-1.3.0-36/`. Ten new posters replace Activity and confirmation with Field Log and real visual comparison across all five native canvas formats. The remaining 24 unchanged posters retain their reviewed artwork. All 34 remote assets are COMPLETE, and each source checksum matches the reviewed release file. The editable project, renderer, native capture trace, review manifest/approvals and ZIP are included. [Release record](release-1.3.0.md) documents devices, validation, privacy boundaries and the Waiting for Review submission.

The sections below preserve the original 1.2.0 imagery provenance. That version was published.

## Original 1.2.0 workspace

`artifacts/app-store-studio-2026-10-08/` contains the MIT-attributed editable Next.js studio, `app-store-screenshots.json`, original captures in `public/screenshots/`, capture trace, export ZIPs, and validation manifest. Its server binds to loopback only at <http://127.0.0.1:52524>. Start it with `node node_modules/next/dist/bin/next dev --hostname 127.0.0.1 --port 52524` after installing the pinned packages. Dependencies can be installed with `pnpm install --frozen-lockfile --ignore-scripts`; Next and TypeScript use their installed binaries directly.

Screens preserve the original UI and aspect ratio. Marketing copy, copper backgrounds, and faithful magnifiers are separate editable elements. There are no fictional device bezels or synthetic app states. Export encodes 24-bit RGB PNGs. `LICENSE.reference` and `PROVENANCE.md` preserve the source editor’s attribution.

## Display groups

| Gallery | Real simulator | Canvas | Count | State |
| --- | --- | --- | --- | --- |
| Large iPhone | iPhone 18 Pro Max / iOS 27.0 | 1320 × 2868 | 8 | Uploaded |
| Standard iPhone | iPhone 17 Pro / iOS 27.0 | 1206 × 2622 | 8 | Uploaded |
| iPad | iPad Pro 13-inch M5 / iOS 27.0 | 2064 × 2752 | 8 | Uploaded |
| Duo outer | iPhone Duo / iOS 27.1 | 1398 × 2034 | 2 | Uploaded |
| Duo inner | iPhone Duo / iOS 27.1 | 2007 × 2853 | 8 | Uploaded |

These are display groups, rather than one gallery for every hardware SKU. App Store Connect supports inherited smaller-device assets; check its placement preview when staging. Dimensions were checked against `asc screenshots sizes --all` and Apple’s [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). Duo inner and outer assets share the Duo display set; total is 34 images.

The sequence covers Home, site brief, deployment history, incident diagnosis, environment drift, build logs, Activity, and confirmation. Duo-specific copy appears only in Duo decks. Compare, natural-language API execution, unsupported OAuth, and completed live mutations are not advertised. Confirmation captures stop before executing the action.

## Capture isolation

Use the Taktung Demo scheme or launch with `-TAKT_DEMO_MODE`. The demo API disables live token connections and does not perform mutations. The bundled example website uses a reserved `.invalid` origin and loads HTML locally. Environment screenshots contain variable names and targets only. Status bars are set to 9:41; start from SpringBoard to prevent another app’s return breadcrumb entering iPad captures.

`capture-trace.json` records the taps and visible UI used for capture. `scripts/package_gallery.py` checks nonblank original captures, expected dimensions, RGB poster mode, and counts, then builds `public/gallery/index.html`. On Duo select `--display=3` for the active inner display and `--display=primary` for the outer display. Native Device Hub controls select the pose; framebuffer dimensions are never spoofed. Source hashes and rendered dimensions live in `export-validation.json`. The studio’s Export bundle button writes ZIPs locally through its guarded export route. Export paths are relative to each display’s own canvas; standard iPhone uses its own capture deck.

## Original 1.2.0 submission

34 RGB compositions were exported, visually inspected, dimension/hash validated, and uploaded. App Store Connect reports COMPLETE for all 34 assets: 8 large iPhone, 8 standard iPhone, 8 iPad, and 10 Duo (8 inner + 2 outer). `scripts/render_duo.py` composes the inner deck offline from the editable project after browser access was blocked by its URL policy. Other decks retain their studio-generated exports. App pixels and aspect ratios remain faithful in both routes.

App Store Connect app `6805738660`, version **1.2.0 (35)**, was submitted as **WAITING_FOR_REVIEW** and is now live. Original submission ID: `777d8ea9-f1af-4802-9301-8d75a324466b`. Exact release notes: “Rendering speed improvements. iPhone Duo support”. Release is automatic after Apple's approval. Receipts and runtime evidence are in `.asc/qa/`; `.asc/qa/release-status.json` contains the precise IDs and monitor command.

The complete artwork package is `artifacts/app-store-studio-2026-10-08/exports/Taktung-AppStore-1.2.0-35.zip`. The source project, original captures, gallery preview and renderer remain editable in the same workspace.


## 1.8.0 (46) reuse — October 21

The optional Settings Tip Jar and updated Other Apps catalog do not change the inspection messages in the existing listing artwork. The 1.8 version retains all 31 number-free native screenshots. Every App Store Connect asset is COMPLETE and its source MD5 matches `artifacts/app-store-1.7.0-44/export-validation.json`; the current receipt is `.asc/qa/release-1.8.0/media-checksum-proof.json`.

Both 18-second App Preview videos are COMPLETE in this version: iPhone `82800019-5a75-84a4-810c-48c3ea62d5b1` and iPad `d8c00019-5a75-84a4-813e-54e60285f54c`. Public availability follows approval of the new App Store release. See `docs/release-1.8.0-46.md` for the actual submission state.
