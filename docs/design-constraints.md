# Design constraints

Product: Taktung (native SwiftUI)
Direction: C Copper rack (seed `de50fe…68e6`), ported from Takt.

## Jobs

- Primary: show the selected site’s production face and whether it is healthy, in one glance.
- Secondary: run Diagnose (heuristic, plus on-device when available).
- Non-goals: dashboard clone, env values, restyling native tabs.

## Required states

- Empty: pick a site.
- Loading / cache: existing banners.
- Error: existing alert banner.
- Success: ALL CLEAR · READY, live face, stamp (PROD / GIT / AGE).

## Platform

- iOS 27 HIG + Liquid Glass chrome only. Content opaque.
- Native `Tab` bar. Form sheets for Settings, site picker, deploy detail.
- Native chrome we will not restyle: tab bar, stack title container, form sheets.

## Type and spacing

- Menlo for IDs, slugs, states, timestamps, the nav site title.
- System text for prose (brief body).
- 8pt grid. Plates 6pt. Diagnose 4pt. Chrome capsules stay pill.

## Color

- Accent copper `#C4784A`. READY mint `#7CDECC`. Iron canvas `#0C0908`.
- One accent. Neutrals carry the app.

## Performance and implementation

- Must not: N+1 `listDeployments` from Home; env values; glass on content.
- Must: reserved preview slot (no layout shift); Diagnose heuristic always; Search tab in demo even if the OS model is unavailable.

## What must not exist

- Repeated domain (title is the site).
- “Production health: Healthy” next to HEALTHY.
- Ghost “View deployments” (the Deploys tab).
- Privacy footnote on Home (Settings).
- Glow, extra labels, candy pills for state.
- Stacked Diagnose / Compare / Logs / Errors results on deploy detail (those are panes).
