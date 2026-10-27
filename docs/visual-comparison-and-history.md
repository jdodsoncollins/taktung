# Visual comparison and persistent history

Included in 1.3.0 (36). The earlier live 1.2.0 (35) binary does not include these changes. See the [release record](release-1.3.0.md).

## Review flow

Open a READY deployment in Deploys → Compare. Enter a relative page path such as `/` or `/about`, choose a reference, and capture. Reference choices come from the selected project's production deployment and its already-loaded deployment list; Compare does not fan out deployment requests across projects.

Each capture renders the page in a fresh anonymous `WKWebView` at 390 × 844 points in light appearance. Capture waits for fonts, visible image decoding, and two animation frames, with an overall 15-second timeout. It bypasses the thumbnail cache. A reveal slider and side-by-side view compare actual PNG pixels. Expand opens a larger native review sheet. Commit, deployment title, route, and capture time identify both images.

Save candidate baseline explicitly replaces that project's saved image for the path. Future captures can compare against this accepted image even after an app restart. Without a reference deployment, the first successful capture can establish a baseline; the UI does not invent a before image.

## Capture boundaries

- READY deployments only, using their HTTPS deployment origin.
- Paths cannot contain an external host, credentials, query, fragment, control characters, or traversal segments.
- Main-frame navigation must remain on the deployment host. Authentication redirects and HTTP failures produce an unavailable/protected message.
- No Safari cookies or Vercel API token enters the page capture session.
- Captures show the initial viewport. They do not exercise interactions, capture the full page, or calculate an automated regression score. Dynamic content and animations can differ between captures.
- Demo uses bundled HTML with deliberate visual differences, in a separate storage namespace. Live capture always loads the real deployment URL.

## Device history

Activity keeps the latest 1,000 records per account/team: API observations, diagnoses, confirmed mutation acceptance and terminal polling results, visual comparisons, baseline saves, and notes. Its Field Log uses local-calendar day sections and supports site/all-site scope, important/notes/changes/issues filters, native search, full entry details and explicit text export. The rail is decorative and carries no implied causal relationships. New entries wait behind a visible button while the reader is away from the top. It is a local journal of this device's actions and observations, not a complete Vercel audit log.

`AppSession` owns the current evidence scope. Restoring history clears the previous scope immediately. Serialized writes prevent clearing history from racing an earlier queued append. Scope and connection guards reject late responses after team changes or disconnect. Comparison requests and note sheets retain their originating scope/site and cannot save into a changed selection. The last authenticated account/team can restore its journal before network authentication finishes, so records remain readable during an API outage.

Replacing a token stages the user, teams, and project list before installing the new API client and evidence identity. A successful replacement clears the previous account's selections, diagnoses, confirmations, and polling. Account/team changes reset navigation; site changes reset deployment and search navigation. The actual selected team is persisted, including an explicit Personal selection. Demo mode is fixed when the session is created.

Failed journal writes remain in the bounded in-memory history and are retried with the next append. The store merges records by ID with existing disk history. A note sheet retains its record ID across write failure and retry; editing and retrying updates that pending note instead of creating a duplicate. If clearing fails, the visible records return and clearing can be retried. Settings exposes local erasure even when authentication is unavailable.

## Storage and privacy

`LocalEvidenceStore` is an actor under Application Support/TaktungEvidence. Account and team directory names are hashed. Versioned JSON files are written atomically with complete file protection and excluded from device backup. Recognizable credentials are redacted before storing or exporting activity; environment-variable values are never requested for evidence.

Baselines contain PNG pixels and provenance in one atomic record. There is one baseline per project/path, with a maximum of 20 per team and 8 MB per image. Saving beyond the cap evicts the oldest capture. Clearing Activity keeps saved baselines; disconnect removes all local evidence for that account across its teams. Corrupt records are reported and preserved rather than silently replaced. No cloud sync or automatic upload occurs.

## Validation

Domain and storage tests cover route/origin validation, READY reference selection, restart persistence, account/team/demo isolation, credential redaction, retention, clearing, stale note/clear scopes, baseline pruning, and corrupt-file preservation. Session regression tests cover failed and successful account replacement, restored team selection, stale detail actions, connection/navigation races, refreshed deployment state, and log failures. Filesystem failure tests cover append recovery and clear retry. A WebKit lifecycle test checks that a late callback cannot fail the next queued thumbnail.

Simulator smoke checks cover actual rendered differences, side-by-side review, expanded review, baseline saving, notes, restart restoration, and preserving comparison state while folding Duo. Runtime screenshots and test receipts are recorded under `artifacts/visual-history/`. See [quality review](quality-review.md) for fixes and remaining validation coverage.

Legacy routine activity labels have a presentation layer (`ActivityItem.displayTitle` / `displayDetail`) shared by rows, detail, accessibility, search and export. Only recognized successful internal labels are translated to readable event descriptions; the stored record is unchanged. Notes, failure evidence and unknown details are preserved. Export still applies credential redaction before presentation.
