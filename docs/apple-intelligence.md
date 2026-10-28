# Apple Intelligence brief lifecycle

Taktung uses Apple Intelligence to rewrite a compact deterministic site brief. It never supplies deployment actions or replaces the evidence calculation. The headline, confidence, next steps and field provenance remain heuristic. Diagnose remains available without an on-device model. Search works on every device; its Apple Intelligence badge and switch appear only when the model is available, or in Demo for screenshots.

Availability uses `SystemLanguageModel.default.availability`, refreshed on foreground activation and before each check. An unavailable model leaves the heuristic in place. Demo summaries remain deterministic even on capable hardware.

## Bounded model work

`BriefModelPolicy` rejects secret-like evidence and limits the snapshot to 2,048 UTF-8 bytes on scalar boundaries. `OnDevicePlanner` measures prompt and instruction tokens using the model's actual tokenizer, then verifies that input plus the 192-token response ceiling and 128-token reserve fit the reported context size. Each generation uses a fresh `LanguageModelSession` and greedy sampling. No accumulated chat history enters a prompt. Build-log and Field Log text may enter only as bounded, redacted excerpts selected by deterministic code (see [on-device context](on-device-context.md)); full log transcripts, runtime log records and environment values never do.

Accepted output is a single line of at most 45 words and 480 characters, ends with sentence punctuation, and passes the existing secret/redaction checks. Invalid or failed responses retain the heuristic. This is a format/privacy gate, not a guarantee that a model can never misstate evidence; the deterministic evidence and provenance remain visible.

## Improvements in local build 42

- The heuristic and its Field Log record publish before optional generation. Generation no longer holds the app's global busy flag, so it cannot block unrelated navigation or inspection.
- Identical in-flight checks share one generation and one check record.
- Accepted bodies can be reused for identical bounded evidence within the same account/team/project. The cache is memory-only, limited to six entries and five minutes; changed evidence requires a fresh session.
- A new site cancels obsolete generation. Request identity and scope checks reject late replies even when an underlying generator finishes after cancellation.
- Disconnect, reconnection, team changes and model unavailability cancel pending work and clear reuse. The cache never persists a model transcript or crosses an account boundary.

These changes reduce avoidable invocations. They do not add background generation or speculative model prewarming. Apple recommends prewarming around strong evidence of user intent with time before a request; an immediate explicit Diagnose tap offers no reliable lead-in window. Keeping useful heuristic evidence immediate and reusing identical completed work is the appropriate behavior here.

## Verification and limits

Six lifecycle tests cover cache bounds/expiry/scope, invalid output, one generation for repeated identical evidence, duplicate coalescing, immediate heuristic publication, site-change cancellation, late reply rejection and disconnect. The complete app run passes 112 tests in `.asc/artifacts/test-shortcuts-final-42.xcresult`. Injected controllable generators verify invocation counts and ordering without pretending that Simulator runs the physical model.

Debug telemetry records input/output token counts, context size, duration and accepted/rejected state without recording snapshot or response text. Physical Apple Intelligence latency, energy use and spoken Siri resolution still require compatible hardware; no physical performance improvement is claimed from simulator evidence.

Apple references: [LanguageModelSession](https://developer.apple.com/documentation/foundationmodels/languagemodelsession), [context management](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window), [prewarming](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:)).

## 1.6 inspection evidence

Fresh domain ownership findings and runtime sample counts can inform the bounded heuristic for five minutes in the same host revision. Only counts and a deployment identity are retained; raw runtime messages and flag values are excluded. Generated summaries must retain sample and ownership qualifications when those findings are present, or the heuristic remains. Scope and model qualification regression tests are recorded in [the 1.6 release](release-1.6.0-43.md).

## Since you last looked

Home compares the loaded deployments (the newest 30) with a mark saved when the person last left the site or the app: when it was, the newest deployment creation time, and the production deployment. `summarizeSinceLastVisit` counts newer deployments by outcome, reports a full page as “at least 30”, and names a production change even without new deployments (a promotion or rollback). The first visit only saves the mark. A return within ten minutes keeps the summary being read, and pull-to-refresh does too; a longer absence reloads the site and starts a new comparison. Marks live in the account/team evidence directory (`visits.json`, at most 50 sites) and are erased with the rest of the account's evidence on disconnect. Demo starts three hours back so the card has content.

Where Apple Intelligence can run outside Demo, the model may restate the facts (the summary plus up to three failed deployments' commit titles and branches, secret-checked, within the 2,048-byte brief bound) as one sentence. `VisitDigestModelPolicy` applies the brief's format checks and discards any reply containing a number, digits or spelled out, that is not in the facts. The deterministic summary shows first, and failed deployments stay listed beneath it either way.

## Search

Search was gated on Apple Intelligence through 1.8.1 but never called the model: it matched “ready”, “failed” and “environment” against the 30 loaded deployments, so requests such as “successful deployments” found nothing. It now shows on every device and works in three stages. Devices without Apple Intelligence use the rules and the live request alone. Where the model can run (or in Demo, for screenshots), the Search page shows an “Apple Intelligence used for deeper searching” badge with a switch, on by default and stored in `UserDefaults`; turning it off keeps stage 2 from running.

1. **Rules.** `SearchRules` maps a request to a `DeploymentQuery`: outcome (ready/successful/passing, failed/broken, canceled, building/queued), Production or Preview, branch (“on main”, “feature/x branch”), commit SHA, time (“today”, “yesterday”, “this week”, “last 3 days”, “24h”), count (“last 5”, “latest deploy”) and quoted commit text. Negation (“didn't fail”) selects the complementary outcomes instead of inverting the request. Exact site names still win, and naming another loaded site offers to switch to it.
2. **Apple Intelligence, only for leftovers.** When the rules leave words unplaced and the model is available (never in Demo), `OnDevicePlanner.planSearch` asks for a `@Generable` plan in a fresh session with greedy sampling, a 160-token ceiling, measured prompt/instruction tokens and schema headroom. The prompt holds only the request (200 characters at most, secret-like text rejected) and up to 30 loaded site names. `SearchModelPolicy` keeps rule-decided filters, accepts a branch, commit text or site only when it appears literally in the request, bounds amounts and counts, and falls back to the rules when the model adds nothing. Results then say “Interpreted with Apple Intelligence on this device”.
3. **Live Vercel request.** The plan runs as one read-only `GET /v7/deployments` with `projectId`, `state`, `target`, `branch`, `sha` (full SHAs only), `since`/`until` and `limit`. Commit text and short SHAs have no server filter, so they are matched on the device over the newest 100 server results, and the caption says so. When no record contains every typed word, `CommitTextMatcher` makes one more pass over the same records with related words: word forms (“fixes”, “fixed”), a short list of developer synonyms (fix/repair/patch, update/bump/upgrade) and up to five close neighbours from the system's on-device English word embedding (`NLEmbedding`). This needs no Apple Intelligence, and results matched this way say so. Every returned record is checked against the plan again before display. Results join the session's known deployments, so detail, logs and confirmed actions treat them like loaded deployments until the site, team or account changes.

The Search screen's states: suggestions with recent searches (memory only, cleared on account/team change, secret-like text never kept), Searching, results with removable filter chips and New search, empty, failed with Try again, choose a site, switch site, environment and no match. The field's clear button or New search returns to suggestions; editing the submitted text does too. Opening a result and going Back keeps the results.

