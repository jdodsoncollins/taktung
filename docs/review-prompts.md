# Native review requests

The user approved the discoverability recommendations on 2026-10-12. Local 1.5.0 (42) uses SwiftUI's StoreKit `requestReview` action after meaningful use. It never asks for a rating at launch or filters users by positive/negative sentiment.

`ReviewPromptPolicy` stores only anonymous dates on this device: first successful use, up to 90 recent inspection days and the last request attempt. Eligibility requires three separate days of successful inspection/comparison and at least seven days since first use. Attempts have a 120-day cooldown. Old use expires after 90 days; clock reversal cannot produce eligibility. A main-actor store reads and persists a fresh request claim before calling StoreKit, preventing two active app windows from requesting together. StoreKit additionally controls whether a prompt is shown.

Completed heuristic/accepted brief checks create scoped opportunities after optional model work finishes. Identical in-flight checks do not create extra opportunities. Successfully persisted comparisons count toward use but do not prompt over the comparison sheet. A check opportunity waits three seconds, then requires active Home, the same account/team/project, no open Settings/site picker/confirmation, no busy/generating work and no pending shortcut route. Site/team/disconnect changes invalidate the opportunity.

Demo cannot record opportunities. Debug builds do not call StoreKit, which avoids interrupting screenshots or unit tests. Seven domain/persistence tests verify day deduplication, minimum use, age, cooldown/expiry, clock reversal and bounded identity-free persistence. The full regression passes **119 tests**, zero failures/skips: `.asc/artifacts/test-discovery-final-42.xcresult`. An unsigned Release generic-device build succeeds. No physical prompt presentation is claimed.

Review preferences contain no account IDs, token values, project names or remote analytics. App Store ratings were not reset. The later explicit submission authorization includes this feature in 1.5.0 (42), now WAITING_FOR_REVIEW; see [release details](release-1.5.0-42.md).

Apple reference: [RequestReviewAction](https://developer.apple.com/documentation/storekit/requestreviewaction).
