# Web Analytics

Implemented for Taktung 1.7.0 (44). Home → Project tools → Analytics is independent of Apple Intelligence and uses the selected project and connected team.

## Evidence and presentation

The public Vercel Web Analytics visits/count endpoint supplies overall visitors and page views. The visits/aggregate endpoint supplies a daily Swift Charts trend and the selected Pages, Referrers, Countries or Devices breakdown. Only one breakdown is loaded at a time, with at most ten named groups plus the server’s Others bucket. Other Apps is documented separately in [the catalog](other-apps-catalog.md).

Seven-day and 30-day requests use completed UTC days. Count’s returned effective bounds become the source of truth; aggregate requests end one millisecond before the exclusive upper boundary to accommodate inclusive bucket alignment. Returned chart/group bounds must match exactly. Daily page-view counts must reconcile with the total; visitors are never summed across segments or days. A clipped or unsupported period never silently becomes a different unlabeled window.

Overall loading, failure, empty and disconnected states are distinct. Breakdown failures leave the accepted total/chart visible. Availability depends on project instrumentation, token role and the account’s reporting window. An HTTP failure or malformed/misaligned payload cannot become zero traffic. Empty numeric values are rejected; true zero traffic includes an instrumentation explanation.

## Boundaries

`WebAnalyticsClient` uses the same ephemeral authenticated REST transport architecture as project inspection, a 25-second request timeout and a 2 MB response cap before decoding. The native connection provides the Keychain token. The client accepts only counts and chosen aggregate fields; no raw visitor/event records are requested. Query strings/fragments are concealed in displayed routes, and text uses the existing redactor. Analytics stays in view memory; it is not persisted in Field Log, cached as a success or added to AI prompts.

AppSession validates account/team/project/reconnection revisions before obtaining the client and after each await. Views invalidate displayed evidence synchronously when their load key changes, cancel obsolete tasks and reject late period/dimension/refresh results. Debug-only isolated Demo sessions provide representative screenshots; live sessions never fall back to Demo traffic.

## Quality verification

The full regression run passed 140 tests; the subsequent 12 session tests passed, including the added delayed-response scope test. This is 141 distinct tests across the two runs. Analytics transport fixtures validate bearer authorization, explicit project/team/production filtering, inclusive aggregate correction, non-additive visitor counts, permission/rate-limit errors, invalid counts and misaligned/doubled dates.

Genuine simulator checks covered compact and large iPhone, iPad, light/dark appearances, seven/30-day switching, referrer selection and the largest accessibility text size. Swift Charts exposes per-day accessibility labels and an expandable native daily-values list.

Authenticated Vercel connector checks for jeremycollins.net returned 153 page views and 67 visitors for October 13–19 UTC. Daily/page/referrer/country/device aggregates reconcile to 153 page views for that exact window. Native transport was tested with deterministic fixtures; simulator screenshots use Demo. Receipts: `.asc/qa/release-1.7.0/` and the [earlier feasibility evidence](web-analytics-feasibility.md).
