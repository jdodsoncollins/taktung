# Apple Intelligence brief lifecycle

Taktung uses Apple Intelligence to rewrite a compact deterministic site brief. It never supplies deployment actions or replaces the evidence calculation. The headline, confidence, next steps and field provenance remain heuristic. Diagnose remains available without an on-device model; Search's model chrome follows actual availability outside Demo.

Availability uses `SystemLanguageModel.default.availability`, refreshed on foreground activation and before each check. An unavailable model leaves the heuristic in place. Demo summaries remain deterministic even on capable hardware.

## Bounded model work

`BriefModelPolicy` rejects secret-like evidence and limits the snapshot to 2,048 UTF-8 bytes on scalar boundaries. `OnDevicePlanner` measures prompt and instruction tokens using the model's actual tokenizer, then verifies that input plus the 192-token response ceiling and 128-token reserve fit the reported context size. Each generation uses a fresh `LanguageModelSession` and greedy sampling. No accumulated chat history, full log transcript, journal or environment values enter the prompt.

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
