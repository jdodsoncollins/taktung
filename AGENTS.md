# Taktung agent notes

Native SwiftUI port of Takt. Keep this repo separate from the Expo Takt
codebase and from MobileflowRN.

- Bundle ID is `com.jcollins.takt` (same as Takt).
- Target iOS 27. Do not set `UIDesignRequiresCompatibility`.
- Site scope = selected Vercel project (header title). Do not N+1
  `listDeployments` from the site picker or Home.
- Live Vercel REST API only for product data. Demo fixtures never mix
  with a live token session.
- Env variable **values** must never appear in UI, Activity, or briefs.
- Mutating actions: allow-list + ConfirmationPolicy + hard confirm.
  READY only after poll.
- Liquid Glass on navigation chrome only; content = opaque HIG surfaces.
- Heuristic Diagnose always works. Hide Search LLM chrome when
  `OnDevicePlanner.isAvailable` is false, except in demo mode (screenshots).
- Prefer unit tests for domain/analysis and API mapping.
- Identity (bundle ID, team, privacy URL) lives in `AppConfig`.
- Update `README.md` and `docs/` when revising architecture.
