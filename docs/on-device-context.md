# On-device context

Four features use what is already on the device: the Field Log, a failed build's log, and recent deployments. Each one works without Apple Intelligence. When the model is available, it helps only with wording or a short summary, and only ever sees a bounded, redacted selection chosen by deterministic code.

The model input policy changed on October 28 at the owner's request. It used to be "no Field Log or build-log text in prompts". It is now "bounded, redacted excerpts only". Full log transcripts, runtime log records and environment values still never reach a prompt. Generated text stays in memory: it is never written to the Field Log, a widget, Spotlight or an export.

## Field Log search

Typing in the Field Log search field still filters the list literally as you type. Submitting the search reads it into filters:

- **Kind:** notes, checks (Diagnose, incident, environment, log and inspection records), comparisons, deploy actions (redeploy, promote, rollback, deploy polls).
- **Outcome:** failed, canceled, problems (both), succeeded, or "didn't fail".
- **Site:** a loaded site name, or "all sites". Either one overrides the screen's site scope.
- **Time:** the same vocabulary as deployment Search ("today", "yesterday", "this week", "last 3 days", "24h").
- **Text:** quoted words, plus any words the rules can't place.

`FieldLogRules` handles common wording on every device. When words are left over, Apple Intelligence is available and the app isn't in Demo, `OnDevicePlanner.planFieldLogSearch` asks for a `@Generable` plan:

- The prompt holds only the request (200 characters at most, with secret-like text rejected) and up to 30 loaded site names. It never includes journal records.
- `FieldLogModelPolicy` keeps every filter the rules already decided.
- It accepts text or a site from the model only when that text or site appears literally in the request.
- It returns nothing if the model adds no new filter, so the rules' reading stands.

Applied filters show as removable chips. When the model was used, the screen says "Interpreted with Apple Intelligence on this device". Removing the last chip clears the search.

## Failed-build explanation

Diagnose on a failed deployment (Home's "Investigate failed build", or the Diagnose pane in deployment detail) keeps the deterministic incident summary. It also adds the build's key log lines:

- `BuildFailurePolicy.excerpt` redacts every line first, then keeps two lines of context around the first and last error-like lines. When nothing looks like an error, it keeps the last eight lines instead.
- The excerpt is capped at 24 lines, 240 characters per line and 2,048 bytes.
- An excerpt that still looks secret-like after redaction is discarded.

These lines appear on every device under "Key log lines". With Apple Intelligence available (never in Demo), a fresh session explains them in one sentence of at most 45 words. `BuildFailurePolicy.accept` rejects the sentence if:

- it quotes text, or names a path, package or error code, that isn't in the excerpt;
- it suggests redeploying, rolling back or promoting;
- it fails the format and secret checks.

The explanation is shown beside the lines it came from. Generation never holds the app's busy flag, and any site, team, account or reconnection change cancels it and clears the evidence.

## Field Log summary

"Summarize the last 7 days" counts the current site's entries, or all sites when the scope is All sites. It counts notes, checks, comparisons, deploy actions, failures and cancellations. Routine records (connections, project and deployment loads) are left out. The counts and the exact entries counted appear on every device.

With Apple Intelligence available, `FieldLogDigestPolicy.prompt` sends the counts and the newest 30 counted entries:

- Each entry is reduced to its date, kind, outcome and title, plus a detail of at most 160 characters.
- Each entry is redacted, and the whole prompt is kept within 2,048 bytes.

The summary may be at most three sentences and 70 words. It is rejected if:

- it contains a number that isn't in the prompt;
- it quotes text that isn't in the prompt;
- it mentions a redeploy, rollback or promotion that the entries don't record.

The card lists "Based on N entries", and each one opens its saved record. The summary is memory only and is cleared on scope changes.

## Spotlight

Settings → Spotlight has two switches. Both are off until the person turns them on.

- **Recent deployments:** the 20 newest deployments of each site the person opens, up to 200 in all, indexed as `DeploymentEntity` (an App Intents `IndexedEntity`).
  - Each one carries the site, status, environment, branch, short commit and commit subject only. All text is redacted, and items that are still secret-like are left out.
  - Selecting a result runs `OpenDeploymentIntent`, which opens the deployment in its site's Deploys tab after the usual account and team check.
- **Field Log notes:** up to 200 of the person's own notes, redacted and shortened. Checks, comparisons and actions are not indexed. Selecting a note opens its Field Log entry.

To open results again, a device-only catalog sits at Application Support/TaktungSpotlight/catalog.json, with complete file protection. It is excluded from backup and erased with the index.

`SpotlightIndexer` is an actor that applies only the newest requested state. A late update for an earlier account, team or setting therefore can't restore removed items. Turning a switch off, changing team or account, and disconnecting all remove Taktung's items. Demo is never indexed. Build logs, runtime logs and environment data are never indexed.

## Verification

`FieldLogQueryTests`, `BuildFailurePolicyTests`, `FieldLogDigestTests`, `SpotlightContentTests` and `OnDeviceContextTests` cover the following with injected generators and a recording indexer:

- rule readings, model policy, grounding and redaction;
- size bounds, scope clearing and Demo behavior;
- what actually reaches each model call.

Simulator runs exercise the UI in Demo, where the model is never called. Physical Apple Intelligence quality, latency and Spotlight ranking need compatible hardware and aren't claimed from these runs.
