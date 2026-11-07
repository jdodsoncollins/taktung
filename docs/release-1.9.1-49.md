# Taktung 1.9.1 (49)

## Scope and authorization

On November 7 the user reported that visual comparisons showed no images ("it is blank"), on more than one project, in the App Store build. The same day the user asked to fix the Home "Project tools" card being cut off on iPad and to check for other layout problems across screen sizes, then wrote "put this on testflight" in the project thread.

This release is an internal TestFlight build only. Nothing was submitted for external beta or App Review. 1.9.0 (48) was already live (READY_FOR_DISTRIBUTION) and was not changed.

## Fixes

- **Blank visual comparison:** the capture task was tied to the Compare view, so anything that removed or re-created the view mid-capture (switching panes, folding a Duo, the split layout re-hosting its panes) cancelled it and discarded the result with no message. It now belongs to the comparison state the deployment screen owns. Only a newer capture or a site change cancels quietly; any other interruption shows a message. See [visual comparison](visual-comparison-and-history.md).
- **Slow or timed-out captures:** capture waited for the window `load` event under a 15-second budget. It now starts at document commit, waits for the parsed document, fonts and on-screen images (each bounded to six seconds) and two frames, within 30 seconds per page. Both pages load at once, Vercel's preview toolbar frame is skipped, and failures name the page and reason.
- **Tall regular-width layout:** an upright iPad (or unfolded Duo held upright) split Home and deployment detail into two half-height panes, clipping Project tools and leaving a gap above the detail tabs. Tall regular-width spaces now get one readable column; wide or folded spaces keep two panes. See [iPhone Duo readiness](iphone-duo-readiness.md).

Branches: `claude/fix-visual-compare`, `claude/fix-tall-screen-layout`, combined with the version bump on `claude/release-1.9.1-49`. None is merged to main.

## Verification

- **Root cause:** reproduced the user's blank Compare screen with the 1.9.0 code by leaving the Compare pane during a capture; the fixed build kept and showed the result. A Release build of the old code also timed out once capturing jeremycollins.net.
- **Live pages (temporary, uncommitted hook in Demo):** the user's production and preview deployments of jeremycollins.net captured in 1.3 to 2.5 seconds on iPhone 17 Pro, iPad Pro (split layout) and Duo (closed) simulators; a missing path showed "This deployment (7f3a21c): The page returned HTTP 404."
- **Unit tests:** `TaktungTests` 221 passed, 0 failed, 0 skipped on the release source (adds stalled-resource, timeout, error-mapping and layout tests).
- **Tip Jar plan:** 6 of 6 passed on the iPhone Air simulator, `Taktung Tips` scheme, parallel testing off. Fresh simulators stop at a system Apple Account sign-in; nothing was entered and those runs are not counted.
- **Screen tour (Demo, automated):** Home, Project tools, deployment detail before and after a capture, Deploys, Activity, Search and Settings on iPhone SE (3rd generation), iPhone 17 Pro Max (portrait and landscape), iPad Pro 11-inch (portrait and landscape), iPad mini and closed Duo in Light; iPhone 17 Pro and iPad Pro in Dark at Large and AX3 text.
- **Not verified:** a partly folded or unfolded Duo (pose controls were not available), physical devices, and live Vercel sessions other than the public page captures above.
- **Known, not changed:** at accessibility text sizes on iPhone, the Compare Reference picker's two-line label is clipped. This predates 1.9.

## Artifact

`Taktung` scheme, Release, archived with no warnings from `claude/release-1.9.1-49` and exported with `.asc/ExportOptions-1.8.0-46.plist`.

`Taktung-1.9.1-49.ipa` is 5,770,145 bytes, SHA-256 `af58481256f712bac442d530c47cc8279c88a26f054f98984e6aea1cbb2cfde5`. The audit found:

- Host and widget both report 1.9.1 (49) with minimum iOS 27.0.
- Strict signatures are valid, debugging is disabled, and both use the existing device-only Keychain group.
- No `.storekit`, StoreKitTest or test-bundle resources, no credential-shaped Vercel token, no `TAKT_UI_TOKEN` bootstrap and no test hook strings are present.
- The canonical privacy URL is embedded.

## Distribution — November 7

- **Build:** `fa0f01b8-7b28-4f97-a504-896fb4a959b3`, **49**, **VALID**, encryption exempt. Uploaded 2026-11-07 21:09 UTC.
- **Internal TestFlight:** **IN_BETA_TESTING** through `Team (Expo)` (`969268ca-e12f-47b5-aba7-79659a1b9f28`) all-builds access.
- **External:** READY_FOR_BETA_SUBMISSION. Nothing was submitted.
- **What to Test (en-US):**

  > Visual comparison fix: Capture comparison now shows the reference and current pages instead of going blank, even if the screen re-lays out while capturing (switching tabs, folding, the Duo split view). Captures start once the visible page is ready and load both pages at once; if one fails, a line names the page and the reason.
  > iPad and unfolded Duo held upright: Home and deployment detail now use one column, so Project tools reads in full and there's no gap above the Diagnose/Compare tabs. Landscape and folded layouts still show two panes side by side.

Monitor without changing anything:

```sh
asc builds info --build-id fa0f01b8-7b28-4f97-a504-896fb4a959b3
asc builds build-beta-detail view --build-id fa0f01b8-7b28-4f97-a504-896fb4a959b3
```
