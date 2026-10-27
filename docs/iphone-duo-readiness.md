# iPhone Duo and Xcode 27.1 readiness

Release candidate: **Taktung 1.2.0 (35)**, bundle `com.jcollins.takt`, iOS 27.0 minimum.

## SDK and project

Built with Xcode 27.1 (27A9275) against iOS 27.1. The signed Release archive reports `DTSDKName=iphoneos27.1`, `DTXcode=2710`, device families `[1, 2]`, and `TAKT_DEMO_MODE=false`. Neither `UIDesignRequiresCompatibility` nor `UIRequiresFullScreen` is present. iPad supports all four orientations. App identity remains in AppConfig.

## Architecture changes

`AdaptiveWorkspace` owns layout, not product state. Compact width uses one ScrollView. Regular width on iOS 27.0 uses two independent scrolling panes. On 27.1, regular width or an active division reserved region uses `ArrangementView` with `.split`; its system layout handles division avoidance. ArrangementView sits inside the navigation stack, outside scrolling content. Only backgrounds ignore safe areas.

Home separates the site face from checks and brief. Deployment detail separates the deployment overview from the selected analysis pane and actions. Site, deployment, navigation, detail pane, loaded logs, and analysis belong above the conditional layout branches. Scroll offsets can reset when the layout switches between compact and split. Native folding checks preserved the selected deployment, Logs pane and loaded content.

System TabView, NavigationStack, and toolbar items handle chrome placement. The principal selected-site button retains its text because site scope is essential. Settings and Refresh have semantic labels. Done in Settings and Sites uses pinned trailing placement. No device-name, idiom, global screen, orientation, or symmetric-inset layout branches were added.

Bootstrap runs once per shared session, preserving the selected site when another window opens. Incident summaries carry their deployment identity and ignore a completion after selection changes. Healthy deployment details explain their state instead of offering a diagnosis for a different failed deployment.

Heuristic Diagnose works without an on-device model. Search follows model availability, except in screenshot demo mode. Demo website previews render bundled HTML through WebKit; demo briefs use deterministic local analysis. Live sessions use the REST adapter and never import fixtures.

## Evidence

- 37 unit tests passed on iPhone Duo / iOS 27.1; 6 feature tests subsequently passed on iPhone 17 Pro, including 2 new site-scope safety cases (39 distinct tests total). Coverage includes model-independent diagnosis, Search availability, repeat bootstrap preserving selection, incident selection scope, demo isolation, API/domain mapping, hard confirmation, env-name-only analysis, and READY polling.
- Final simulator build and signed Release archive succeeded without compiler warnings or errors.
- Real captures verify compact iPhone 17 Pro and iPhone 18 Pro Max, regular-width iPad Pro 13-inch, and the Duo outer display in its current simulator pose.
- Static App Resizability audit found no remaining fixed screen/idiom/orientation/inset assumptions in this change.

## Native runtime smoke results

After unlocking, Device Hub checks passed on the real iPhone Duo simulator poses: inner portrait and landscape, partial folding, closing and reopening, and Split View on both left and right. The failed deployment and selected Logs pane survived folding. Each compact placement kept navigation, pane selection and actions readable and scrolling independently. Native site selection changed the header to the selected project; on-screen keyboard input entered `failed` and returned the expected demo lookup. Settings, Sites, confirmation and larger-text layout were also checked. No simulated framebuffer resizing substitutes for native poses.

Evidence: `.asc/qa/duo-folded-landscape.png`, `duo-split-left.png`, `duo-split-right.png`, and `native-smoke-final.json`. The eight inner screenshots are actual 2007 × 2853 captures. This is simulator smoke coverage; physical-device endurance and every combination of text size, keyboard and fold angle were not exhaustively tested.

## Release submission

**Taktung 1.2.0 (35) is now live**. It was submitted October 8, 2026 at 10:16 PM Pacific. Submission ID: `777d8ea9-f1af-4802-9301-8d75a324466b`. Version ID: `9d991720-cbb9-4e52-8e5d-192973b8e50d`. Build ID: `64141dd4-a0e2-41f6-829a-c2d62a004d5f`. The user-authorized exact release notes are “Rendering speed improvements. iPhone Duo support”. Apple validation reported zero blocking issues; the final dry run matched the intended VALID build. All 34 screenshots are COMPLETE. Release type is AFTER_APPROVAL.

The signed production archive is `.asc/artifacts/Taktung-1.2.0-35-release.xcarchive`; the exported IPA is `.asc/artifacts/Taktung-1.2.0-35.ipa`. Distribution signing uses a dedicated local keychain and App Store profile; protected private material stays outside the repository. Public receipts are in `.asc/qa/review-submit.json`, `review-status-final.json`, `validation-final.json` and `release-status.json`.

Monitor with `asc review submissions-get --id 777d8ea9-f1af-4802-9301-8d75a324466b --output json`.

Release smoke testing fixed the previously identified action dispatch: promote uses `/v10/projects/{projectId}/promote/{deploymentId}` and rollback uses `/v1/projects/{projectId}/rollback/{deploymentId}`. Both poll deployment readiness and the current production target before recording success. Redeploy still creates a deployment. Site changes invalidate confirmations and stale deployment loads, and confirmation captures its action before SwiftUI dismissal. The API adapter prioritizes `targets.production` over the newest build and redacts credential assignments and recognizable credentials from log text before display or analysis. Unit/API mapping tests cover these repairs. No live Vercel mutation was performed.

Apple's Icon Composer renderer revealed blank dark/tinted icons. Replacing direct `hidden=true` with a default visibility specialization corrected appearance overrides. Default, Dark, and TintedDark now render recognizable marks. Actual Home Screen inspection verified the copper/cream Default icon and mint/charcoal Dark icon; Default appearance was restored. Evidence: `.asc/qa/icon-rendered-*.png`, `icon-light.png`, and `icon-dark-native.png`.

Live Vercel smoke testing passed in a production-mode simulator session using the existing App Review credential: authentication, six live projects, selection of the FTU site and 20 scoped deployments. An earlier simulator request timed out; the unlocked-session retry succeeded. `.asc/qa/live-deployments-native.png` records the live deployment list. No live Vercel mutation was performed; action dispatch, confirmation safety and polling are covered by unit/API tests and isolated demo checks.


## 1.3.0 follow-up

The 1.4.0 follow-up is [submitted for review](release-1.4.0.md). Fresh actual pose/rotation controls and native LCD captures verified both display appearances and selection retention. The [current regression report](ui-refresh-2026-10-11.md) distinguishes this simulator layout evidence from unverified physical gesture/posture performance. The paragraph below records the earlier 1.3.0 submission, which is now live.

The new minor release includes real comparison, persistent history and the Field Log composition. Duo folding/rotation retained comparison evidence; both native displays received fresh feature imagery. The full 67-test suite passed, icons were inspected in Default and Dark modes, and 34 listing assets were verified COMPLETE. Version 1.3.0 (36) is Waiting for Review after the authorized October 10 submission. See [the release record](release-1.3.0.md) for exact IDs, receipts and coverage.
