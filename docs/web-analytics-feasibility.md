# Web Analytics feasibility

Verified October 20, 2026. This is research for a future feature; it is not included in the submitted 1.6.0 (43) binary.

Vercel's [public Web Analytics API](https://vercel.com/docs/analytics/web-analytics-api) exposes production visitors/page views, time-series and dimension aggregates, and custom event counts. The [May 18 announcement](https://vercel.com/changelog/web-analytics-api) confirms that it uses the dashboard's aggregated data model. This is a separate contract from the Observability/CPU/runtime metric work in the October 17 study.

## Live evidence

The current project behind jeremycollins.net is `jeremy-collins-dot-net`, not the older `v0-project`. Verified domains include the apex redirecting to www.jeremycollins.net and its production Vercel alias. The website source contains `@vercel/analytics/next` and renders `<Analytics />`. Project metadata omitted the optional analytics objects, despite successful analytics queries; a missing field is not proof that collection is disabled.

Authenticated read-only calls returned **153 page views and 67 visitors** for production from October 13 00:00 UTC through October 20 00:00 UTC (the completed October 13–19 window). `/taktung` had 10 page views and 5 visitors in that same period. Daily and top-page breakdowns, including the server's Others row, reconcile to 153 page views. These are Web Analytics aggregates, not raw visitor records or all HTTP requests. Do not sum visitor counts across segments to claim a unique audience.

Live validation used the connected Vercel account. The official guide supports bearer access tokens, so the native implementation can retain Taktung's Keychain/PAT architecture. The native token's current permissions still need checking during implementation. No token was copied, no analytics configuration was changed, and no release/review action was taken for this research. Safe query/response evidence is in `.asc/qa/web-analytics-2026-10-20/verified-contract.json`.

## Contracts and date handling

- `GET /v1/query/web-analytics/visits/count` supplies pageviews and visitors.
- `GET /v1/query/web-analytics/visits/aggregate` supplies bounded groups using `by`, `since`, `until`, `filter` and `limit`.
- Event count/aggregate endpoints support custom events already emitted with `track()`; they do not instrument a site automatically.
- Every request must explicitly carry the current project and team, with production filtering and guarded publication after account/team/project changes.
- Preserve the server's returned effective query range. Count and aggregate endpoints aligned the same requested bounds differently. For a seven-day daily chart, the aggregate's inclusive upper date initially added an eighth bucket. An aggregate upper bound one millisecond before October 20 00:00 UTC returned the intended seven buckets and reconciled with the count result. Verify this contract with native transport tests rather than treating a date label as evidence.
- Respect the account's reporting window and permissions. Unsupported, disabled, empty, restricted, failed and stale are distinct states; a missing response is not zero traffic. Keep Others separate from the actual named pages.

## Proposed native surface

An Analytics destination under Project tools would fit the existing workflow: visitor/page-view totals, a Swift Charts traffic trend, an explicit date window, top pages and referrers. Countries/devices can be secondary breakdowns. Offer longer ranges only when available. Loaded deployment timestamps could annotate the chart without implying that deployment changes caused a traffic change.

Follow the existing native text styles, adaptive opaque surfaces and teal accent. Fetch only the selected site's evidence. Keep the project scope and freshness visible; retain only bounded secret-free aggregates if caching is later implemented. Querying visitors is independent of Apple Intelligence. Any later brief integration should consume a compact, qualified summary rather than raw visit/event records.
