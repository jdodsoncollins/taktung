# Project inspection in 1.6

Home → Project tools exposes read-only evidence without requiring Apple Intelligence. The native deployment list separately supports text search, Production/Preview selection and All/Failed/Building filters. A null Vercel target is treated as Preview, while production keeps the API's production-target semantics. Filters apply only to the loaded site snapshot.

## Data contracts

| Tool | Request | Presentation boundary |
| --- | --- | --- |
| Vercel activity | `GET /v3/events`, `projectIds`, `teamId`, `limit=50`, `withPayload=true` | Allow-listed event type, actor, target and timestamp. Raw event text/payload values are discarded. Distinct from Field Log. |
| Domains | `GET /v9/projects/{id}/domains`, `limit=50` | Names, redirect routes and ownership verification; no uptime/TLS/DNS claim. |
| Deployment checks | `GET /v1/deployments/{id}/checks` | Up to 100 returned checks, registered/running/completed status and actual conclusion. Empty means no configured checks, not passing. |
| Cron jobs | `GET /v9/projects/{id}` | Up to 50 `crons.definitions`, path without query, UTC schedule, disabled/configured state. No execution-history claim. |
| Feature flags | `GET /v1/projects/{id}/feature-flags/flags`, `limit=50` | The `data` envelope supplies names, kinds and archived/configured state. No SDK keys, variants or targeting values. |
| Build logs | `GET /v3/deployments/{id}/events`, `builds=1`, `follow=0`, `direction=backward`, `limit=500` | Newest bounded window reversed into chronological order. Search, timestamps, error-like filtering, explicit copy/share of redacted loaded lines. |
| Runtime logs | `GET /v1/projects/{project}/deployments/{deployment}/runtime-logs` | One deployment stream, incremental NDJSON/SSE framing, up to 500 records / 2 MB. Search and error filtering are local to the received sample. |

The runtime endpoint is the [documented deployment stream](https://vercel.com/docs/rest-api/logs/get-logs-for-a-deployment). The separate project-history API used by the official CLI is not silently substituted. No last-hour error rate, continuous monitoring, billing estimate or site-wide metric is inferred from the stream. A quiet connection reports no records received. Stop and scope/navigation cancellation end the consumer and its producer task; finite completion or failure shows a stopped state with an explicit restart.

Inspection responses are capped at 2 MB before JSON decoding. Runtime records are individually capped at 256 KB; visible messages at 8,192 characters. Build messages are capped at 16,384 characters. The general live adapter uses an ephemeral session and an 8 MB maximum response, with a tighter 2 MB build-log ceiling. Requests have timeouts. Missing/malformed envelopes throw; 401, 403, 404, 429 and general request failures remain different from successful empty results. Refresh replaces evidence rather than retaining old rows under a new scope.

## Ownership and lifecycle

`ProjectInspectionClient` owns HTTP/framing/mapping. It conforms to `ProjectInspectionAPI`, inherited by the existing live/demo API protocol. `AppSession` validates an `InspectionScope` containing account/team evidence, selected project and host revision before and after awaits. A deployment-specific tool also validates that the deployment belongs to the selected project's loaded or current production snapshot.

View state owns rows, search and filters. `.task(id:)` ties reads to scope/deployment/reload changes; runtime Stop changes that task's key. No eager tool requests run from Home or the site picker. There is no per-project deployment fan-out. Debug demo tools use the isolated demo client and never become live fallbacks.

The Field Log records build-log load metadata, not raw build/runtime transcripts. Remote Vercel events are displayed independently. New privacy filtering strips terminal escapes, recognized assignments and credentials, password-bearing URLs, and URL query text before log evidence enters the UI or user-initiated copy/share. Runtime paths strip query strings and fragments. Activity and flag mappings discard value-bearing fields by construction.

## Compact briefs

The session retains only domain ownership counts and runtime sample counts/identity, in memory for up to five minutes. Account/team/project/reconnection revisions clear these observations. A late stream cannot record counts for another scope. No raw runtime line, URL query, environment value or flag variant enters the model prompt.

Heuristics remain immediate. Existing token budgeting, fresh model sessions, response limits, scoped reuse and cancellation remain in place. Runtime error summaries must retain a sample qualification; domain findings must retain ownership/verification context. Generated responses missing those qualifications are rejected in favor of the heuristic.

## Visual behavior

Project tools and Deployments use native large proportional page identity. Divided rows share a leading edge, restrained teal symbols, secondary metadata and opaque adaptive neutral backgrounds. Logs use relative Menlo; navigation and prose use SF text styles. Native search drawers, pickers, toggles, back navigation and share sheets retain system behavior. Forced app Light/Dark/System appearance applies to every reader. Dynamic Type wraps rows and descriptions; the largest accessibility size remains scrollable with Stop reachable in navigation chrome.

## Verification and limits

The 1.6 regression passes 132 tests. New tests cover routes/team/project parameters, real envelope mapping, empty versus forbidden/malformed evidence, check semantics, payload privacy, duplicate identities, split UTF-8/SSE records, record-size limits, log/deployment filtering, late scope responses, disconnected scopes and model qualification rejection.

Live API and simulator checks used the user's authorized connected workspace. Production metadata matched the API; the selected site's build viewer displayed all 60 returned lines in chronological order. Searching `cache` yielded five lines; copying produced the expected redacted text. Domains displayed three ownership-verified records with the configured apex redirect. Checks, cron definitions and flags were genuinely empty. Activity showed actual deployment and alias events.

A quiet live runtime connection was opened and stopped from the UI, including at the largest accessibility text size; no runtime records arrived during that observation. Transport framing/privacy were exercised with synthetic URLProtocol streams. No production fault or deployment mutation was injected. Physical on-device model latency, Siri execution and new hardware posture/gesture performance are not established by these simulator checks.

The Duo iOS 27.1 smoke launched the app and opened Project tools. An explicit active outer-LCD capture verified the rows alongside native vertical navigation. The default screenshot selected the inactive inner display and was black; no framebuffer resizing or inner-pose claim substitutes for that missing coverage.

Metrics/spending discovery, customer invoice history, provider storage enumeration and alert history remain separate contract/capability investigations from the [research](vercat-research-2026-10-17.md). They are not represented by nonfunctional destinations in this release.
