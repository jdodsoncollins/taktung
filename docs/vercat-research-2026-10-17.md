# Vercat implementation research

Research date: 2026-10-17. Input: the user's ten Vercat screenshots, Vercat's published product/privacy pages, current Vercel API documentation and OpenAPI specification, official Vercel CLI source, and Taktung's current Swift sources.

Implementation follow-up: the core log/activity/domain/check/directory work and tested read-only cron/flag adapters are included in [1.6.0 (43), deployed to internal TestFlight](release-1.6.0-43.md). See [project inspection](project-inspection.md) for implemented contracts and live verification. The research findings below remain the original study; metric/spending and invoice/storage/alert work is not implied by the new beta.

## What is confirmed

Vercat describes a direct iPhone-to-Vercel architecture with the PAT in Keychain. Its developer says selected context and API caches remain local, with environment responses and runtime logs excluded from its persistent query cache. The privacy policy identifies RevenueCat for subscriptions and PostHog for telemetry and experimental-feature switches. This supports a local client with several independent data adapters; it does not establish the UI framework, query library or exact endpoints used by each screen. [App listing](https://apps.apple.com/us/app/vercat/id6799833372), [developer privacy policy](https://www.vercat.dev/privacy).

No verified public source repository for this iOS product was found. The similarly named public `developwithnikhil/vercat` repository is a React web project with a different identity; it is not implementation evidence for Pingting Tu's app. No Vercat binary, intercepted traffic or private repository was inspected. The API mapping below establishes how the features can be implemented, rather than claiming knowledge of Vercat's private code.

The product website explicitly describes its Codex/Claude buttons as handing logs and project context to ChatGPT or Claude Code. That supports interpreting screenshot 9 as an external context handoff; it does not prove an agent is executing deployment actions inside Vercat. The same site describes deployment actions as read-only in v1 and environment editing as guarded by a remote switch. [Developer product page](https://www.vercat.dev/).

## Screenshot-to-API map

Paths below were checked against Vercel's [published OpenAPI specification](https://vercel.com/openapi.json). They are implementation options, not a captured Vercat request trace. A documented route still needs validation against the intended token, team, role and plan.

| Screenshot / feature | Implementation path | Taktung implication |
| --- | --- | --- |
| 1: connected account | Existing user/team requests and device Keychain storage; retain account identity separately from the token input. | Taktung already uses this architecture. Multiple saved accounts would be a separate feature. |
| 2, 4, 6, 10: deploy list and production | Projects and deployment responses supply target, framework, status, commit message, branch, SHA and creation time. Filter by target independently of build state. | We already fetch most underlying data. Add text search and explicit Production/Preview filtering; retain production-target semantics rather than equating the newest deploy with production. |
| 9: build log viewer | `GET /v3/deployments/{idOrUrl}/events` supports JSON and streaming. Search, timestamps, refresh and copy are presentation features on top. | Existing client fetches up to 100 lines by default; detail UI displays only the last 40. A searchable bounded viewer is a concrete improvement without inventing a new data source. |
| 5: runtime logs | Documented deployment stream: `GET /v1/projects/{projectId}/deployments/{deploymentId}/runtime-logs`. It returns `application/stream+json`. | Add a separate runtime-log adapter and UI. Current build-log text is not runtime evidence. See the historical-query distinction below. |
| 8: remote activity | `GET /v3/events` supports `teamId`, `projectIds`, date/type/principal filters, pagination and optional payloads. | This can show real deploy/alias activity. Keep this remote feed distinct from the local Field Log. Project scoping can happen on the server; no project-by-project deployment fan-out is needed. |
| 3: deployment checks | Deployment checks and the newer project check/run APIs expose configuration and results. | Show configured, pending, passing, failed and unavailable states explicitly. An empty check list cannot establish a pass. |
| 5, 10: domains | `GET /v9/projects/{idOrName}/domains` provides the selected project's domain records. Additional DNS/certificate routes serve different inspection tasks. | Implement domain inspection as real evidence; names, verification results and configuration status are different from actively probing uptime or TLS reachability. |
| 5: cron jobs | `GET /v9/projects/{idOrName}` contains `crons.definitions`, originating deployment and enabled/disabled timestamps. Definitions include path, schedule and host. | A read-only schedule view is straightforward. Schedule configuration is not execution history or proof of a successful run. Do not expose secret-bearing query parameters. |
| 5, 10: feature flags | Public project flag/settings/segment APIs exist, including `GET /v1/projects/{projectIdOrName}/feature-flags/flags`. | Read-only inspection is feasible. Flag edits are deployment-affecting mutations and must enter Taktung's confirmation workflow. Do not display SDK secrets. |
| 2: requests, CPU, bandwidth, errors, latency | Metric discovery and aggregate queries exist in the official CLI and published schema; availability varies. | Add an explicit supported-metric catalog and a time window, unit, scope and freshness for every result. Do not manufacture a value from a missing metric. |
| 7: invoices and usage | Public FOCUS charges can provide dated usage/cost records. A general customer invoice-list route was not found in the inspected spec. | Cost inspection is plausible; issued invoice history remains a separate capability investigation. Do not treat the Marketplace partner invoice API as an account invoice-list API. |
| 10: storage and alerts | The spec has store lookup by ID, while provider resource enumeration needs more mapping. Alerts have plan/configuration requirements. | A navigation row alone does not prove complete data coverage. Investigate provider discovery and alert-history contracts before promising these tools. |

Relevant individual references: [runtime stream](https://vercel.com/docs/rest-api/logs/get-logs-for-a-deployment), [user events](https://vercel.com/docs/rest-api/user/list-user-events), [project checks](https://vercel.com/docs/rest-api/checks-v2/list-all-checks-for-a-project), [flags](https://vercel.com/docs/rest-api/feature-flags/list-flags), [store lookup](https://vercel.com/docs/rest-api/storage/get-a-store).

## Runtime history differs from the deployment stream

Vercel's official CLI uses `https://vercel.com/api/logs/request-logs` for project request-history queries. Its source passes project/owner, time bounds, page, deployment, environment, severity, status, request and branch filters. This is first-party implementation evidence, but is a different host and contract from the documented `api.vercel.com` deployment stream. It should not silently become Taktung's default API base or be advertised as an equivalent stable REST contract. [Pinned CLI source](https://github.com/vercel/vercel/blob/c628be7835e03a965b93e9cf9e2bd5ac2acbf5eb/packages/cli/src/util/logs-v2.ts).

A Swift implementation can use `URLSession` byte streaming with incremental decoding, a bounded memory buffer, cancellation when leaving the screen or switching scope, and guarded publication after account/team/project revalidation. First validate framing and response limits against real responses; `application/stream+json` is not proof that arbitrary chunk boundaries align with complete JSON records. Never use a partial log sample to claim the entire last hour was error-free. Historical access and retention require a separate capability result. [Runtime log behavior and limits](https://vercel.com/docs/logs/runtime).

## Metrics and spending have concrete first-party precedents

The official CLI discovers metrics through `/v2/observability/schema` and supports `/v2/observability/query`. It also has a newer `/metrics/v1` catalog/query contract. The implementation constructs explicit scope, metric, aggregation, date range, granularity and filters; it validates available aggregations and units. These are read queries even where HTTP POST is used. Neither this code nor the screenshots proves which contract Vercat chose. [Pinned metric discovery](https://github.com/vercel/vercel/blob/c628be7835e03a965b93e9cf9e2bd5ac2acbf5eb/packages/cli/src/commands/metrics/schema-api.ts), [pinned metric query](https://github.com/vercel/vercel/blob/c628be7835e03a965b93e9cf9e2bd5ac2acbf5eb/packages/cli/src/commands/metrics/query.ts).

Most metrics require Observability Plus, while basic Observability is available on all plans. The metric catalog, actual token permissions and response state must determine which cards are shown. A sensible native result model separates loaded value, genuine empty result, unavailable, permission denied, unsupported plan, stale cache and failed request. `0`, an em dash and a loading indicator are not interchangeable. [Current Observability guidance](https://vercel.com/docs/observability).

`GET /v1/billing/charges` is a documented team-scoped FOCUS JSONL feed with daily granularity and a maximum one-year range. Preserve currency, charge period and cost semantics; billing data is not a source for a live p95 latency card. Its allowed roles are documented. Actual customer invoices differ from estimated consumption and from invoices submitted by Marketplace partners. [Billing charge API](https://vercel.com/docs/rest-api/billing/list-focus-billing-charges), [Marketplace invoice API](https://vercel.com/docs/integrations/create-integration/marketplace-api/reference/vercel/get-invoice).

Vercel Alerts currently require Pro or Enterprise with Observability Plus. Their documented delivery options include webhooks, but a durable webhook/notification service would change the architecture of a phone-only client. No particular Vercat alert API or push implementation was verified. [Alerts](https://vercel.com/docs/alerts).

## Typography and layout observations

These are visual observations from the supplied images, not a recovered font specification:

- Large, bold proportional page titles establish clear hierarchy. Supporting section titles are smaller and semibold; row content uses a regular proportional face. The result looks consistent with iOS system typography, but the exact family and weights cannot be established from screenshots.
- Monospace is reserved for commit/branch metadata and console output. This contrast makes technical evidence easy to distinguish from navigation and explanatory prose.
- Most content uses flat rows, separators, a shared leading edge and generous section spacing. A small number of summary containers carry denser statistics. Larger text and fewer nested boxes make the breadth easier to scan.
- A native translation for Taktung is `.largeTitle` for top-level page identity, `.headline` for sections, `.body` for task/commit titles, and `.subheadline`/`.caption` for metadata, with Dynamic Type. Keep teal/adaptive neutrals, accessible secondary text, opaque content and glass navigation. These are proposed roles; this research does not replace current tokens.
- Taktung already uses proportional system UI text and relative Menlo identifiers. The useful change is hierarchy, layout density and evidence visibility, rather than adding a new font package or copying Vercat's black/blue palette or cat artwork.

See [Apple typography guidance](https://developer.apple.com/design/human-interface-guidelines/typography), [Taktung typography implementation](../Taktung/DesignSystem/Theme.swift) and [current design system](../DESIGN.md).

## State handling worth improving on

Screenshot 2 labels checks as passing, while screenshot 3 for the shown deployment says they are not configured. Without source or traffic this cannot be diagnosed, but Taktung should never collapse an absent check result into a pass. A deployment being READY is not evidence of runtime health.

Screenshot 7 displays a general error above an issued-invoice list. It may represent independent requests with different outcomes, rather than fabricated data. Keep failures attached to the affected section, with a precise explanation and freshness for any retained records. A project-switch recommendation is inappropriate for an error in a team-scoped billing request.

The zero metrics in screenshot 2 may be valid. Screenshots alone do not establish whether their time range, permissions, retention and missing-value behavior are correct. Empty resources/checks and an error state do not validate every tool listed in the directory.

## Best fit for Taktung

1. Improve the existing build-log reader: search the loaded bounded records, show timestamps/levels, refresh and copy a redacted selection, and label the loaded window accurately.
2. Add read-only Vercel activity, domain inspection and actual check results. These have clear API contracts and fit the current selected-site model.
3. Add real runtime evidence with explicit stream/history capabilities; use observed evidence in existing diagnosis and compact on-device briefs. Existing `BoundedOpsContext` runtime/domain fields are integration hooks, not proof that these feeds are already fetched.
4. Add a discoverable tool directory reachable without an LLM. It can live under Home while model-only Search stays capability-gated. Add read-only cron/flag tools after their adapters are tested.
5. Prototype metric discovery and billing charges against authorized scope before building summary cards. Investigate invoice history, storage enumeration and alert history separately; do not ship a directory of nonfunctional destinations.

Any addition keeps one selected-site scope, bounded requests, no Home/site-picker N+1, account/team invalidation, and no environment values in UI, briefs or history. Remote activity should be visibly identified as Vercel evidence; the Field Log remains a local record of the user's inspections and notes. Flag, environment and deployment changes continue through allow-listed confirmation workflows. External AI handoff, if added, should preview a small redacted context package and require the user's share action; tokens and environment values never enter it.

No app code, metadata or App Store submission was changed by this research. These are grounded implementation candidates, not newly approved product commitments. No authenticated customer API or billing query was performed.

## Reproducibility

Official CLI source was pinned to `c628be7835e03a965b93e9cf9e2bd5ac2acbf5eb`. The public OpenAPI snapshot fetched on 2026-10-17 had 336 paths and SHA-256 `0dc5069cda5a3ea5541491fe5b188f16e1d1e022aa3a160a1694b8eacf91bd36`. Unauthenticated temporary source copies are outside the repo; only the findings and public citations are retained here. Public documentation and first-party CLI contracts can evolve, so verify them again before implementation.
