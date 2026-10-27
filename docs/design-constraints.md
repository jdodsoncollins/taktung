# Design constraints

Product: Taktung, native SwiftUI. Current direction: release inspection, a task-focused variation of familiar developer-tool conventions. The user's Vercel screenshots guide hierarchy and restraint; the composition and teal accent remain Taktung's own. The prior copper workbench exploration in [UI identity](ui-identity.md) is historical.

## Jobs and hierarchy

Home shows the selected site's production state, page evidence and commit first, followed by a directly reachable comparison task. Checks form a quieter group. Deployments provide inspection panes and an explicitly confirmed action menu. Activity keeps the persistent Field Log's native scope, filters, search and entries.

## Platform

- iOS 27 minimum, Xcode 27.1 SDK. Native tabs, navigation stacks, menus, sheets and confirmation dialogs own interaction.
- Liquid Glass belongs to navigation chrome. Content is opaque semantic surfaces.
- Home and detail use AdaptiveWorkspace: one column at compact width, two panes at regular width, and ArrangementView for active Duo division regions on 27.1. Navigation and evidence state sit outside layout branches.
- Only backgrounds ignore safe areas. Long site titles truncate in the middle without overlapping toolbar buttons; accessibility retains their full label.
- Settings stores System/Light/Dark selection. A System choice follows the root's effective system scheme, including during an open sheet.

## Type, space and color

System text expresses hierarchy and states. Monospace is reserved for commits, paths and build logs and scales with Dynamic Type. Content spacing follows the shared 8-point scale. Plates use 12-point radii and subtle separator borders; task rows are at least 44 points tall. At accessibility text sizes, ornamental thumbnails give their space to text.

Neutral light/dark surfaces carry the app. Teal is selection and link tint. Semantic ready, building and failure colors accompany explicit labels and SF Symbols. The light cream/copper and dark mint app icon remain recognizable identity assets in Settings.

## Data and execution constraints

Selected project is the site scope. Home and site selection never fan out deployment requests across projects. Product data comes from live REST only; marketing demo fixtures remain isolated. Environment values never enter UI, briefs or history. Canceled deployments are described as canceled, with no invented failure cause.

Heuristic Diagnose always works. Apple Intelligence availability controls model-only chrome and is refreshed on activation. Search returns navigable sites/deployments from loaded resources, exact site matches precede state keywords, and quick searches retain their results. Model output cannot execute an action. Mutations retain allow-list, confirmation policy and hard confirmation; READY requires polling.

The built design tokens and component rules belong in DESIGN.md and .impeccable/design.json after independent finish review.
