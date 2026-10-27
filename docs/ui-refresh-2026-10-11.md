# Native UI refresh and regression checks

The user chose a working native implementation inspired by their Vercel mobile references, without copying its exact interface or colors. The redesign leads with production evidence, makes Compare reachable from Home, groups checks into familiar rows, and moves deployment mutations into a native action menu. Light, Dark and System are persistent settings. Taktung's icon changes appearance with the UI; the Other Apps page uses official bundled Codable artwork and readable spacing.

## Bugs fixed

- Search's main CTA previously returned a static hostname/state string. A hostname now returns a selectable site; deployment queries return routes to actual loaded deployment details. Exact site names take precedence over state keywords.
- Query change callbacks cleared quick-search results immediately after creating them. The submitted query now owns result validity.
- Long hostnames overlapped compact toolbar controls. The principal label now has a bounded width and middle truncation, preserving its full accessibility name.
- A canceled deployment was diagnosed as a generic build failure. Cancellation now has a distinct low-confidence explanation and asks the operator to inspect cancellation rather than fix an invented root error.
- System mode could leave an open Settings sheet in the prior forced appearance. The presentation now resolves System from the root's effective scheme.
- Apple Intelligence availability remained cached after launch. Foreground activation and each check refresh availability; removing Search availability returns the tab selection to Home.

## Apple Intelligence context and responsiveness

The heuristic snapshot is published immediately. Only its body enters the model request, bounded to 2,048 UTF-8 bytes on scalar boundaries. Credentials are rejected before truncation; assignments and PAT formats are rejected at input/output boundaries. Each brief uses a fresh session, preventing transcript accumulation. The actual tokenizer measures prompt and instructions against the model's contextSize, reserving 192 response tokens plus 128 tokens of headroom. Greedy generation returns one short sentence; empty, verbose, incomplete or secret-like output falls back to the heuristic. Generation is user-triggered and only one brief runs at a time.

Two live simulator requests were accepted: canceled FTU production used 119 input / 15 output tokens in 5,303 ms; READY portfolio production used 128 / 23 in 4,756 ms. Both had a 4,096-token model context. These measurements describe Simulator behavior. The paired physical iPhone 17 Pro Max was unreachable (CoreDevice tunnel unavailable), so physical-device inference latency is unverified. Metrics contain counts/timing only; prompts and responses are not logged.

This follows Apple's [context management](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window) and [generation options](https://developer.apple.com/documentation/foundationmodels/generationoptions) guidance. The app requires iOS 27 already, allowing real token counts and usage reporting.

## Regression evidence

The full suite passed: 79 tests, zero failures/skips, no compiler warnings/errors. The result bundle is `/Users/jeremycollins/Library/Developer/XcodeBuildMCP/workspaces/taktung-707327848c8d/result-bundles/test_sim_2026-10-11T23-32-52-549Z_pid19449_76dc2176.xcresult`. It covers API mapping and production target selection, stale scope protection, confirmation safety, polling, privacy, history/baselines, captures, Search and model policy.

Live UI values were compared with read-only Vercel REST responses for jdodsoncollins' projects: FTU revision CANCELED (b702a03), portfolio/v0 READY (b9afe42), Codeatrophy READY (c54faf4), Pinest READY (e24a82f). The exact reported hostname opened its site, and the failed-deployment result opened the matching canceled commit. No live deployment mutation was executed. Native capture evidence and sanitized expected fields live under `.impeccable/review/`; these are separate from fictional marketing captures.

Appearance checks covered forced Light on a dark device, forced Dark on a light device, Dark persistence after relaunch, and System switching while Settings remained open. Both Settings icon variants and the spacious Other Apps page were inspected.

The largest Dynamic Type capture exposed compressed heading/status and commit/age rows. At accessibility sizes these now stack, and ornamental task glyphs yield their width to text. The correction compiled without warnings and was verified in a fresh native capture. Real demo comparison captures, the reveal handle, side-by-side mode, expanded inspection and baseline saving were also exercised in the refreshed UI.

The compact demo baseline was saved through its confirmation, then the app was terminated and relaunched. The saved-baseline event and capture record remained visible in Field Log. The Redeploy menu opened its explicit confirmation and was dismissed without executing. Large iPhone build 38 also completed native capture, expanded side-by-side inspection with provenance, Field Log navigation, forced Light settings and the spaced Other Apps page. The listing uses the existing editor export path rather than a new renderer.

The tablet pass found internal wording in legacy activity records. `ActivityItem.displayTitle` / `displayDetail` now present recognized successful routine events in plain language, leaving persisted records, notes, failures and unrecognized details intact. Rows, detail, accessible labels, search and redacted export use the same presentation. Ten focused Field Log/comparison tests passed (zero failures/skips/warnings), including two new history-projection cases; receipt: `.asc/qa/tests-1.4.0-history.json`. Build 39 includes this correction and supersedes build 38.

The fresh independent finish reviewer inspected all 28 required native captures, the three user references and primary SwiftUI code. Its sole material finding was the token prompt's contrast. The explicit semantic prompt fixed it: native recaptures measured 6.14:1 in light and 6.76:1 in dark. The verdict is ship at that review scope. `.impeccable/review/finish-review-1.md` and `finish-verdict-1.md` preserve the reports. A separate fresh documenter wrote `DESIGN.md` and `.impeccable/design.json` after the correction.

Duo checks used a fresh iOS 27.1 simulator and actual browser pose/rotation controls. Closed outer, open inner, book, tabletop and tent captures retained the selected site's state/commit. The inner display was checked in portrait and landscape, and both displays in light/dark. Display 1 is the outer LCD; display 3 is the inner LCD. The 3D mirror image was unavailable, so new Settings/comparison/history tap flows were exercised on phone and iPad; the Duo listing uses Home appearance captures. Physical Duo gesture/posture performance is unverified.

The final listing format follows the user's later request for a visual distinction from Codable: flat numbered inspection sheets, compact captions, aligned full app captures and no floating device treatment. Nineteen genuine native sources were exported through the attributed editor's existing browser renderer. Four App Store display sets cover large iPhone, standard iPhone, iPad, and Duo inner/outer. See [release evidence](release-1.4.0.md) for the final upload and review state.
