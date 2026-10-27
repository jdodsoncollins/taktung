# App Store metadata and discoverability, 2026-10-12

The user first requested widget copy and discoverability recommendations, then approved implementation with “Do all this.” The approved name, subtitle, description, keywords, promotion, categories and product/support URLs are verified in App Store Connect. Product/support pages are published and native review-request cadence is implemented. A later explicit instruction authorized submitting all completed features: **1.5.0 (42) is WAITING_FOR_REVIEW**, with these metadata changes and 25 listing images included. Public 1.3.0 remains the live listing until approval. The audit and proposals below preserve the pre-change findings; the final implementation and access limits are recorded at the end.

Canonical metadata is now under `metadata/app-info/en-US.json` and `metadata/version/1.5.0/en-US.json`. Keep proposals outside that tree until selected. Pull against the editable app-info record explicitly; the app has separate live and editable records. Receipts and the pre-edit snapshot are in `.asc/qa/metadata-1.5.0-42/`.

## Initial widget-only edit

What's New:

> Rendering speed improvements. iPhone Duo support. Bug fixes and UI updates.
>
> New small, medium and large Home Screen widgets show deployment status and recent activity, with an optional project filter.

The description adds:

> See the latest deployment status and recent deploy counts in small, medium and large Home Screen widgets. Filter a widget to one project or keep All projects; the large widget also shows recent deployment activity. Widgets follow your device's light or dark appearance.

At this first step all other existing fields were preserved. Validation had zero errors and two existing support-URL warnings: it redirected from `jeremycollins.net` to `www.jeremycollins.net` and resolved to the portfolio root. The dry run identified only description and What's New updates; the apply and read-back confirmed those changes. The later approved implementation resolves both URL warnings.

## ASO audit of the pre-change editable metadata

| Field | Current value | Characters / limit |
| --- | --- | --- |
| Name | Taktung | 7 / 30 |
| Subtitle | Vercel deploy and incident ops | 30 / 30 |
| Keywords | `taktung, vercel, deploy, incident, ops, production, rollback, preview, dns, ssl, logs` | 85 / 100 |
| Promotional text | Empty | 0 / 170 |
| Description, after widget addition | Current description with the new widget paragraph | 1,637 / 4,000 |
| What's New, after widget addition | Original requested notes plus widget paragraph | 201 / 4,000 |
| Primary category | Utilities | — |
| Secondary category | Developer Tools | — |

| Check | Finding |
| --- | --- |
| Keyword duplication | `taktung`, `vercel`, `deploy`, `incident`, `ops` repeat indexed name/subtitle words. |
| Keyword separators | Ten spaces after commas consume character budget. Only 40 characters remain after removing those spaces and the duplicated entries. |
| Field utilization | Keywords are below the skill's 90-character heuristic. Filling the field is useful only with relevant, researched terms; avoid padding for the count. Subtitle already uses its full allowance. |
| Missing fields | Required description, subtitle, keywords and What's New are present. Promotional text is optional and currently unused. |
| Description coverage | Current `dns` and `ssl` terms are absent from the description. Prioritize the product's actual inspection tasks when researching replacement terms. |
| Cross-locale gaps | Only en-US exists; no duplicate translated keyword sets can be audited. |
| Apple app tags | The API returned no tags, so classification alignment is unavailable. |
| Ranking/popularity evidence | Astro MCP is unavailable and Apple Ads has no configured profile. No keyword rank, popularity, difficulty or competitor-gap scores were obtained. |

Apple identifies title, subtitle, keywords and category as search relevance signals, alongside downloads, ratings and reviews. The following changes are relevance/conversion hypotheses, not evidence that these terms have high search volume or that metadata alone explains low downloads. [Apple search guidance](https://developer.apple.com/app-store/search/).

## Metadata proposal, subsequently approved and applied

| Field | Proposed value | Characters / limit |
| --- | --- | --- |
| Name | Taktung: Deployment Status | 26 / 30 |
| Subtitle | Vercel logs, compare & widgets | 30 / 30 |
| Keywords, research candidate | `production,rollback,preview,build,devops,hosting,history,release,incident,health,ci,cd,inspection` | 97 / 100 |
| Primary category | Developer Tools | — |
| Secondary category | Utilities | — |

This preserves the Taktung brand and bundle identity while explaining the job at a glance. Deployment status is clearer to a new user than incident ops, and the subtitle introduces comparison and widgets. The candidate keyword set avoids exact name/subtitle duplicates and malformed separators. Validate demand and relevance per storefront before swapping it in; the list is not a measured ranking recommendation. Do not add competitor app names or unrelated AI terms.

The category proposal matches the app's developer audience. It is not a promise of improved ranking. Apple states that categories participate in discovery and search. The currently staged first three screenshot sheets already tell the proposed story: production, real comparison and quick-glance widgets. Keep that order clear rather than adding unverified claims about screenshot OCR indexing. [Apple product-page guidance](https://developer.apple.com/app-store/product-page/).

## Description proposal

Use the first sentence for the deployment job. Move the name's etymology to the website/About screen; a new visitor needs to understand the app before its history. The full 1,410-character alternative is [app-store-description-proposal.txt](app-store-description-proposal.txt). It includes widgets, Siri/Shortcuts, real comparison, local history, explicit confirmation and device/model requirements without promising continuous uptime monitoring or automatic recovery.

Suggested opening:

> Check your Vercel deployments from your iPhone or iPad. Taktung brings production status, build logs, visual comparison and a local Field Log into one place.

Suggested 151-character promotional text for when 1.5.0 is released:

> Check your latest deployment from the Home Screen. Small, medium and large widgets show recent deploy status and activity for all projects or one site.

Promotional text can change independently of a version, but does not affect App Store search ranking. Since widgets are not yet publicly shipped, keep this as a release-time proposal. Description copy should explain genuine benefits, not become a keyword list. [Apple product-page guidance](https://developer.apple.com/app-store/product-page/).

## Google search and the linked website

At audit time the support URL opened the portfolio home page. Taktung appeared as one project among others, with older feature/capture wording. The proposal was a dedicated, indexable Taktung page with app-specific title text, accurate screenshots, setup information and a direct App Store link. These pages are now implemented and published as recorded below.

Proposed page brief, for the website repository:

- A dedicated URL such as `/taktung`, linked from the portfolio and the app's marketing metadata once it exists.
- Page title: **Taktung — Vercel deployment status and widgets for iPhone**.
- Main heading: **Check Vercel deployments from your iPhone**.
- A concise introduction, production/comparison/widget captures, and an honest explanation of local history and project filtering.
- A setup/FAQ section addressing personal access tokens, project/team scope, widget refresh/freshness and Apple Intelligence availability. Label unreleased features until publication.
- A dedicated support page/contact route, separate from the marketing page and privacy policy.
- A canonical URL, sitemap inclusion and Search Console inspection. Clear titles and visible headings help Google understand the page; indexing and ranking are not guaranteed. [Google title guidance](https://developers.google.com/search/docs/appearance/title-link).
- Accurate `SoftwareApplication`/`MobileApplication` structured data matching visible product information. Validate against the current Google requirements; use real pricing/review data and do not invent ratings. [Google software-app guidance](https://developers.google.com/search/docs/appearance/structured-data/software-app).

## Measure before broadening

Record a baseline of App Store Search impressions, product-page views, first-time downloads and search conversion by territory for a complete period before the metadata release. Compare equal periods after indexing settles, and track the candidate phrases in the same storefront. App Analytics search totals can include Apple Ads traffic; separate that context when interpreting changes. Low impressions and low conversion need different responses. No App Analytics report was collected in this audit. [Apple measurement guidance](https://developer.apple.com/app-store/search/).

The public US listing currently lacks enough ratings for an aggregate overview. A native review request after a successful meaningful inspection or comparison is a useful product proposal; do not ask at launch. Do not reset existing ratings with the update. [Public listing](https://apps.apple.com/us/app/taktung/id6805738660), [Apple ratings guidance](https://developer.apple.com/app-store/product-page/).

After the English positioning has been measured, localize for territories where actual impressions/downloads justify it, with store-specific keyword research. Avoid translating every locale as an unmeasured growth tactic.

## Approved implementation, 2026-10-12

The user said “Do all this.” The previously proposed descriptor **Taktung: Deployment Status**, subtitle **Vercel logs, compare & widgets**, 97-character keyword set, 1,410-character description and 151-character promotional text are now applied and verified in editable 1.5.0. Primary category is Developer Tools, secondary Utilities. Widget release notes remain intact. The earlier tables describe the audited pre-change snapshot; the proposal headings above are historical. Current canonical metadata is in `metadata/`. This does not imply measured keyword popularity or a ranking improvement.

Published the dedicated product page at https://www.jeremycollins.net/taktung and support at https://www.jeremycollins.net/taktung/support. Both return HTTP 200 and appear in the published sitemap. Updated the portfolio's Taktung entry and linked summaries. Metadata now uses these marketing/support URLs and validates with zero errors/warnings. The static product page includes genuine unchanged listing exports, setup/FAQ, accurate SoftwareApplication/MobileApplication data with no invented ratings, canonical metadata and system-theme styling. Widgets/Siri remain labeled upcoming. Website changes are in the separate `/Users/jeremycollins/Projects/JeremyCollinsDotNet` repository. Production deployment: `dpl_BFiaKHn7qPiEDtKDSXAa8m2Q4jCG`.

Website validation: 15 existing tests pass, TypeScript checking and production build succeed, live HTML/schema/sitemap checks pass, and browser checks cover desktop plus 390-pixel light/dark phone layouts, image loading and support navigation. An inherited global header background was corrected during browser QA before deployment.

Native review requests are implemented with a restrained usage cadence; see [review prompts](review-prompts.md). The current app regression passes 119 tests and unsigned device compilation. Existing ratings were not reset. At the metadata-only step review remained withdrawn. The user's later explicit authorization submitted all completed features in build 42, including this cadence, with 25 updated images; current state is WAITING_FOR_REVIEW and automatic release after approval. [Release record](release-1.5.0-42.md) contains signed archive/export, final readiness and submission evidence.

Measurement access remains incomplete: the current App Store Connect API key returned permission denied for analytics, and the web analytics page requires Apple sign-in. No reliable App Store Search baseline was collected. The signed-in Google account has no Search Console property; property verification awaits the user's explicit browser-access confirmation. Keyword popularity/rank tracking remains unavailable. Private analytics/deployment diagnostics are outside the repository at `/tmp/taktung-discovery.mSS3Qg`; no report URLs, credentials or raw business analytics are committed.

The selected-image preview is `.asc/qa/metadata-1.5.0-42/listing-selection.png`; the 25 original exports remain unchanged in `artifacts/app-store-1.5.0-42/`. They were subsequently uploaded during the separately authorized release task; remote checksums, order and COMPLETE state are in `.asc/qa/release-1.5.0-42/`.
