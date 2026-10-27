---
name: Taktung
description: Native release inspection with real page comparison and a local field log.
colors:
  accent-light: "#146B65"
  accent-dark: "#7BD6CD"
  canvas-light: "#F5F6F8"
  canvas-dark: "#111416"
  surface-light: "#FFFFFF"
  surface-dark: "#1B1F22"
  surface-muted-light: "#EEF0F2"
  surface-muted-dark: "#272C30"
  text-secondary-light: "#59636B"
  text-secondary-dark: "#ACB6BD"
  action-light: "#263237"
  action-dark: "#E3E9EB"
  text-on-action-light: "#FFFFFF"
  text-on-action-dark: "#182125"
  text-on-accent-light: "#FFFFFF"
  text-on-accent-dark: "#112D2A"
  danger-light: "#B42318"
  danger-dark: "#FFABA3"
  ready-light: "#23734F"
  ready-dark: "#8BD9AF"
  building-light: "#8A5A08"
  building-dark: "#EDC47C"
typography:
  page-title:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "34pt"
    fontWeight: 700
  title:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "22pt"
    fontWeight: 600
  detail-title:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "20pt"
    fontWeight: 600
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17pt"
    fontWeight: 600
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17pt"
    fontWeight: 400
  body-medium:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17pt"
    fontWeight: 500
  subheadline:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "15pt"
    fontWeight: 400
  subheadline-semibold:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "15pt"
    fontWeight: 600
  footnote:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "13pt"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12pt"
    fontWeight: 500
  caption:
    fontFamily: "-apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "12pt"
    fontWeight: 400
  identifier:
    fontFamily: "Menlo, monospace"
    fontSize: "13pt"
    fontWeight: 400
  identifier-small:
    fontFamily: "Menlo, monospace"
    fontSize: "12pt"
    fontWeight: 400
  path:
    fontFamily: "Menlo, monospace"
    fontSize: "14pt"
    fontWeight: 400
rounded:
  plate: "12pt"
  md: "12pt"
  button: "8pt"
spacing:
  xs: "4pt"
  sm: "8pt"
  md: "12pt"
  lg: "16pt"
  xl: "24pt"
components:
  button-primary-light:
    backgroundColor: "{colors.action-light}"
    textColor: "{colors.text-on-action-light}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.button}"
    padding: "0pt 12pt"
  button-ghost-light:
    backgroundColor: "{colors.surface-light}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.button}"
    padding: "0pt 12pt"
  plate-light:
    backgroundColor: "{colors.surface-light}"
    rounded: "{rounded.plate}"
    padding: "{spacing.lg}"
  chip-selected-light:
    backgroundColor: "{colors.surface-light}"
    typography: "{typography.subheadline-semibold}"
    rounded: "{rounded.button}"
    padding: "8pt 12pt"
  chip-unselected-light:
    textColor: "{colors.text-secondary-light}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.button}"
    padding: "8pt 12pt"
  search-field-light:
    backgroundColor: "{colors.surface-light}"
    rounded: "{rounded.button}"
    padding: "{spacing.md}"
  path-field-light:
    backgroundColor: "{colors.surface-muted-light}"
    typography: "{typography.path}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
  state-ready-light:
    textColor: "{colors.ready-light}"
    typography: "{typography.label}"
  reveal-handle-light:
    backgroundColor: "{colors.accent-light}"
    textColor: "{colors.text-on-accent-light}"
    typography: "{typography.body-medium}"
    size: "44pt"
  button-primary-dark:
    backgroundColor: "{colors.action-dark}"
    textColor: "{colors.text-on-action-dark}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.button}"
    padding: "0pt 12pt"
  button-ghost-dark:
    backgroundColor: "{colors.surface-dark}"
    typography: "{typography.body-medium}"
    rounded: "{rounded.button}"
    padding: "0pt 12pt"
  plate-dark:
    backgroundColor: "{colors.surface-dark}"
    rounded: "{rounded.plate}"
    padding: "{spacing.lg}"
  chip-selected-dark:
    backgroundColor: "{colors.surface-dark}"
    typography: "{typography.subheadline-semibold}"
    rounded: "{rounded.button}"
    padding: "8pt 12pt"
  chip-unselected-dark:
    textColor: "{colors.text-secondary-dark}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.button}"
    padding: "8pt 12pt"
  search-field-dark:
    backgroundColor: "{colors.surface-dark}"
    rounded: "{rounded.button}"
    padding: "{spacing.md}"
  path-field-dark:
    backgroundColor: "{colors.surface-muted-dark}"
    typography: "{typography.path}"
    rounded: "{rounded.md}"
    padding: "{spacing.sm}"
  state-ready-dark:
    textColor: "{colors.ready-dark}"
    typography: "{typography.label}"
  reveal-handle-dark:
    backgroundColor: "{colors.accent-dark}"
    textColor: "{colors.text-on-accent-dark}"
    typography: "{typography.body-medium}"
    size: "44pt"
---

# Design System: Taktung

## Overview

**Creative North Star: "Code-review inspection"**

Taktung uses the familiar discipline of a code review: readable state, precise identifiers and evidence that can be inspected. Neutral surfaces and system controls keep the interface calm; teal identifies an interaction or selection. The comparison reveal and dated Field Log provide its distinctive grammar.

This is a native SwiftUI system. San Francisco text styles, platform navigation and opaque content carry the visual language. The recognizable app icon appears in Settings; its colors do not become a decorative console theme. The selected site stays legible in navigation chrome while related evidence can occupy one compact column or two usable panes.

**Key Characteristics:**

- Adaptive light and dark content with a persistent System appearance option.
- System typography with Dynamic Type; monospace reserved for identifiers, paths and logs.
- Opaque tonal surfaces with quiet separators; platform glass belongs to navigation chrome.
- Real before/after page evidence and a dated local journal.

Recorded from the final native build, its direction contract and the finish review. The final verdict is `ship` for the reviewed correction: the Settings token prompt now uses secondary text, with reported contrast of 6.14:1 in light and 6.76:1 in dark. The scoped [icon C review](.impeccable/review/icon-c-finish-review.md) records construction, fidelity and Settings evidence; its [final verdict](.impeccable/review/icon-c-finish-verdict.md) is `ship` for the resolved identity persistence fix. These design records do not establish App Store submission state.

## Colors

A cool neutral ground supports one restrained teal interaction tint and separate semantic deployment states. The frontmatter contains the exact light/dark values from `Palette`; use each pair together. Native `Color.primary` supplies primary text, and UIKit `separator` supplies borders. Those semantic colors remain platform-owned rather than receiving invented fixed hex values.

### Primary

- **Quiet Teal** (`accent-light`, `accent-dark`): links, native control tint, selection affordances and the reveal divider/handle.
- **On-Teal Ink** (`text-on-accent-light`, `text-on-accent-dark`): the comparison handle symbol; use the paired foreground rather than assuming white in both appearances.

### Secondary

These are semantic states, not additional brand accents.

- **Ready Green** (`ready-light`, `ready-dark`): confirmed successful deployment state and successful outcomes.
- **Building Amber** (`building-light`, `building-dark`): queued, initializing and building states.
- **Error Red** (`danger-light`, `danger-dark`): error, blocked and canceled deployment states, failure details and destructive native actions.

### Neutral

- **Canvas** (`canvas-light`, `canvas-dark`): the app, scroll and window ground.
- **Surface** (`surface-light`, `surface-dark`): opaque plates, grouped task rows, selected filter chips and custom fields.
- **Muted Surface** (`surface-muted-light`, `surface-muted-dark`): route fields, comparison ground and unloaded thumbnail slots.
- **Secondary Ink** (`text-secondary-light`, `text-secondary-dark`): provenance, descriptions, timestamps, neutral state and readable field prompts. `textTertiary` deliberately aliases this same role.
- **Action Ink** (`action-light`, `action-dark`) with **On-Action Ink** (`text-on-action-light`, `text-on-action-dark`): the filled primary task button. The shared component's accent role uses this neutral pairing.
- **Platform Primary / Separator**: primary text and thin edges follow native semantic colors. Settings grouped rows keep system grouped-list surfaces.

**The Interaction Tint Rule.** Use teal for interactive tint, selected affordances and the comparison divider. Deployment state uses its own semantic text and symbol.

## Typography

**Body and title font:** San Francisco through native SwiftUI text styles.
**Identifier font:** Menlo, scaled relative to `.subheadline` or `.caption` by `MonoFont`.

The frontmatter point sizes are the native default-size equivalents of the recorded semantic styles, not fixed layout sizes. SwiftUI text styles and Dynamic Type are authoritative. There is no custom display face, fixed line-height scale or tracked uppercase label system.

The October 17 [Vercat study](docs/vercat-research-2026-10-17.md) informed the 1.6 deployment page title and Project tools directory: large proportional identity, quiet metadata and flat divided rows. Inspection, build-log and runtime readers use native searchable lists with opaque neutral backgrounds; monospace stays reserved for evidence. Taktung retains its adaptive neutrals/teal and native accessibility. The competitor's exact font remains unverified; no artwork or brand palette is copied.

### Hierarchy

- **Page title** (`.largeTitle`, bold): Deployments and Project tools.
- **Title** (`.title2`, semibold): Production, Field log and first-level task headings.
- **Detail title** (`.title3`, semibold): deployment title in the overview.
- **Headline** (`.headline`): section and journal entry titles.
- **Body / Body medium** (`.body`): prose and tasks; medium weight for custom primary button and comparison-task titles.
- **Subheadline / Subheadline semibold** (`.subheadline`): metadata, descriptions and filters; semibold for site chrome and dated journal groups.
- **Footnote** (`.footnote`): capture status, storage notices and supporting details.
- **Label / Caption** (`.caption`): deployment state, timestamp and provenance; medium state words with monospaced digits.
- **Identifier / Identifier small / Path**: relative Menlo for commit references, log lines and editable page routes. The route style is relative to `.subheadline`; the small identifier style is relative to `.caption`.

**The Identifier Rule.** Use Menlo only for commits, paths, deployment identifiers and build logs. Titles, task labels, narrative and journal prose use system text styles.

**The Reading Size Rule.** Keep native text styles and relative font scaling. At accessibility sizes, reflow metadata vertically and remove optional thumbnails or ornamental row symbols before reducing legibility.

## Layout

The spacing rhythm is 4, 8, 12, 16 and 24 pt. Standard content inset and plate padding use `lg`; related rows use `md`, and larger groups use `xl`. Compact workspaces scroll in one column. Each expanded pane scrolls independently with a readable content maximum of 760 pt and a 16 pt inset.

On iOS 27.1, regular width or an active native division region selects `ArrangementView` with split arrangement. The system owns usable regions and fold divisions. The regular-width fallback uses two side-by-side panes; compact fallback stacks the same content. Selection and comparison state live above the workspace, so layout changes do not create a new review session. This is a size-class/region system, not a set of guessed pixel breakpoints.

At accessibility text sizes, Production state and commit age stack vertically; optional production thumbnails and task symbols disappear. Journal title and timestamp stack, entry details lose the three-line limit, and scope/filter controls can stack through `ViewThatFits`. Other Apps hides its optional icon while preserving wrapping body copy. Custom buttons, filter chips and journal menu controls use a 44 pt minimum target.

The site title truncates in the middle inside native chrome, with the full title retained for accessibility. Maximum title width is 210 pt in compact and 360 pt in regular width.

## Elevation & Depth

Content uses opaque tonal layering and thin native separators. No custom content shadow vocabulary is present. Plates and custom task rows have a 0.5 pt semantic separator stroke; Field Log's 1 pt temporal rail gives entries continuity without raised cards. Native bars, toolbar controls, tab/sidebar adaptation and sheet chrome supply system material and transition behavior.

**The Chrome Material Rule.** Let native navigation provide Liquid Glass. Content surfaces remain opaque, with tonal separation and semantic separators.

The only explicit custom timing in the sampled UI is the Field Log jump to new entries: 0.2 s ease-in-out, disabled when Reduce Motion is active. The comparison reveal follows drag/slider position directly. Push, sheet and dismissal transitions remain system-owned.

## Shapes

Content plates use continuous rounded rectangles (`plate`); comparison canvases and route fields use the same-sized `md` role. Custom buttons, chips and search fields use the tighter `button` role. These roles remain distinct even where their values match. Do not turn unused `stamp` or `card` declarations into future component defaults.

Production summary thumbnails are 76 × 112 pt with 12 pt corners. Smaller deployment-list thumbnails are 30 × 48 pt with 4 pt corners. They show real captured page pixels when available and keep a muted placeholder slot while loading. The reveal handle is a 44 pt circle centered on a 2 pt vertical teal divider; its center clamps inside the canvas edge.

## Components

### Buttons

Quiet task controls, with the platform owning navigation actions.

- **Primary:** neutral Action Ink and its paired foreground, body medium text, `button` corners, 12 pt horizontal padding and 44 pt minimum height.
- **Ghost:** opaque Surface with platform primary text and a 0.5 pt separator edge; used for retry and incident-summary tasks.
- **Disabled:** shared custom button opacity is 0.45; busy/empty conditions disable the relevant controls.
- **Navigation and mutation actions:** use native buttons and menus. Destructive choices use native destructive roles and explicit confirmation; they do not become a standing filled action stack.
- **Focus / activation:** native controls own keyboard focus and touch feedback. There is no hover-dependent product affordance.

### Chips

Compact filters for deployment state and detail panes. Selected chips use opaque Surface, primary text, semibold subheadline and a thin separator edge. Unselected chips have a transparent ground and secondary text. Both use `button` corners, 8 pt vertical/12 pt horizontal padding and 44 pt minimum height. Detail-pane filters scroll horizontally.

### Cards / Containers

The shared Plate contains related evidence with `plate` corners, Surface ground, `lg` padding and a thin separator edge. Home's comparison task uses the same silhouette; Checks groups simpler task rows with internal native dividers. Settings uses native inset-grouped lists and preserves system row geometry.

### Inputs / Fields

Search has an opaque Surface field with `button` corners, `md` padding and a thin separator edge. The comparison route uses Muted Surface, `md` corners, `sm` padding and relative Menlo. Settings uses a native secure token field in a grouped row. Enabled prompts use Secondary Ink; the corrected token prompt keeps its accessible label. Text entry avoids automatic capitalization and correction where a path, query or token requires precision.

### Navigation

Native `TabView` with sidebar adaptation contains Home, Deploys and Activity, with Search gated by capability. Each section has a `NavigationStack`. Toolbar chrome keeps the selected-site title between Settings and the contextual trailing action. Sheets are focused tasks with native Done/dismissal controls. The persistent segmented Appearance picker offers System, Light and Dark; the app and Settings sheet apply the same selection.

### Real visual comparison

A candidate and reference are captured as actual page images at 390 × 844 in light appearance. A segmented control switches Reveal and Side by side. Reveal masks the baseline over the candidate, with a draggable circular handle and an accessible native slider. Side by side uses an 8 pt gutter and the same capture aspect ratio. A 12 pt rounded opaque canvas clips the evidence. Below it, baseline/candidate stamps preserve commit, deployment title, route and capture time. Expand opens native review chrome; saving a baseline requires confirmation. These captures document pixels at the page top, not page-interaction test results.

### Field Log

A plain list groups persistent local observations by Today, Yesterday or calendar date. A 24 pt SF Symbol marker and thin rail sit beside the entry title, timestamp and detail. Notes use body text; operational descriptions use subheadline. Failed/canceled outcomes include explicit words. Site scope, event filter and native search narrow the visible record. New arrivals wait behind a new-entry affordance while the reader is away from the top. Detail, note, export and clearing controls remain native and scoped.

### Identity and Other Apps

Settings uses the actual TaktungMark asset at 52 pt with 12 pt corners, not a recreated symbol. Other Apps follows an aligned icon/title/body row with a native external-link SF Symbol, 16 pt horizontal relationship, 12 pt vertical row inset and a wrapping description. CodableMark is 60 pt with 14 pt corners and hides at accessibility sizes. Origins and appearance variants are recorded in [Settings image provenance](docs/settings-icon-provenance.md): TaktungMark comes from verified Icon Composer light/dark renders; CodableMark is the developer's official App Store artwork.

### Selected icon C

The user selected **C, the abstract metronome**, initially implemented for 1.5.0 (40). Build 41 corrects its structural alignment. An open neutral frame and broad base hold one diagonal teal pendulum and a round counterweight. A clear gap where the pendulum crosses the right leg preserves the silhouette at small sizes. The split inspection frame and overlapping evidence pages remain unchosen studies. The selected icon reuses the interface's paired neutral/teal colors.

The Default/light, Dark and Tinted appearances share frame paths, pendulum endpoints and width, and counterweight coordinates. Keep that silhouette and layer geometry. Use the paired Canvas/Surface, Action Ink and Quiet Teal tokens, balancing each appearance optically rather than inverting it wholesale. Preserve the recognizable tinted/mono silhouette and crossing gap. Avoid text, tiny log lines, status checkmarks, AI sparkles and Vercel's triangle: the mark identifies an inspection tool, not a deployment outcome.

**The Centered Icon Structure Rule.** The body and base share x=512 on the 1024 px source canvas in every appearance. Body mirror pairs sum to 1024; the 652 px base spans x=186–838. Preserve the unchanged directional pendulum and counterweight, with 10 px local clearance beyond the pendulum edge and counterweight disk. The complete mark remains directional because its pendulum is angled. [Centering proof](.asc/qa/icon-1.5.0-41/centering-proof.json) records the coordinates; appearance layers retain zero translation.

The standard Icon Composer `.icon` document contains separately editable frame, pendulum and counterweight SVG layers with separate Default/light and Dark background fills. Tinted retains the three independent foreground parts and uses automatic system fill. Prefer simple supported vectors. Let the system supply the app-icon mask and material treatment; source art should not bake in bevels, highlights or shadows. This platform icon treatment does not change the opaque-content rule inside the app.

Apple Icon Composer ictool rendered all three centered appearances and 120 px small previews; Xcode built and archived the selected document. The 52 pt Settings mark comes from the verified build 41 Default/light and Dark renders, with native iPhone/iPad light/dark integration inspected. The installed Home Screen capture verifies the system-selected Dark icon; Default/light is verified in the renderer and Settings. Apple's processed build 41 icon also preserves the centered structure. Settings artwork follows the resolved in-app System/Light/Dark selection; Home Screen icon appearance remains system-owned. Keep provenance and affected listing captures in sync. [Icon direction](docs/icon-direction.md) records the tradeoffs and implementation; the [centering review](.impeccable/review/icon-c-center-review.md) records the scoped `ship` verdict and evidence limits. This records verified 1.5.0 (41) artwork; the submitted release state is tracked in docs/release-1.5.0.md.

### Marketing format

Taktung's listing originally used numbered inspection sheets. The October 20 update removes sequence-number badges while preserving left-aligned copy, genuine app captures and restrained neutral/teal grounds. The October 17 user request updates this format with measured Apple device bezels, bold headlines and larger captions using the primary text color. Existing seven feature messages stay unchanged; new feature copy may be added when needed. These are flat, straight-on compositions distinct from Codable's promotional imagery. Avoid decorative tilt, shadows, fictional app UI and invented fold lines. Use the attributed App Store screenshot studio and preserve source aspects.

The 1.6 package has 28 exports: eight each for large/standard iPhone and iPad, plus two expanded landscape Duo and two closed portrait Duo sheets. It includes genuine small/medium and large widget captures. Headlines are 1.69–1.93 times their prior font size, with weight 700; primary caption contrast is 14.20:1 in light and 16.84:1 in dark. Thumbnail and full-size inspection precede upload approval. See [App Store imagery](docs/app-store-imagery.md) and `artifacts/app-store-1.6.0-43/PROVENANCE.md` for source, bezel and renderer records. Icon-bearing retained Settings and widget captures remain representative of centered C in build 43.

## Do's and Don'ts

### Do:

- **Do** use the paired appearance tokens and keep System, Light and Dark available in the persistent Settings picker.
- **Do** use native navigation stacks, tabs, menus, sheets, segmented pickers and confirmation dialogs.
- **Do** preserve 44 pt minimum controls, readable wrapping and Dynamic Type reflow.
- **Do** pair status color with a word and SF Symbol.
- **Do** show actual page pixels with baseline/candidate, commit, route and capture-time provenance.
- **Do** keep Field Log entries dated, scoped and readable as a local record.
- **Do** keep Taktung's app icon and Settings mark coherent, preserve artwork origins, and retain Codable's official artwork and appearance handling.

### Don't:

- **Don't** apply glass, gradients or custom shadows to content plates.
- **Don't** add a decorative console theme around identity artwork or copy Vercel's literal interface and colors.
- **Don't** use monospace, uppercase eyebrows or decorative technical labels for ordinary UI prose.
- **Don't** replace real comparison captures with decorative thumbnails, invented test scores or usage metrics.
- **Don't** expose environment variable values in UI, journal entries or briefs.
- **Don't** present model-only Search chrome when unavailable, except in isolated demo mode.
- **Don't** make deployment actions appear completed before confirmed polling establishes the resulting state.

Evidence boundary: the current icon finish packet reports four shipping app rasters with embedded provenance and no missing attribution. Its review is scoped to the icon and Settings integration; unchanged app surfaces were not reopened. Native SwiftUI is outside the HTML/CSS detector, so no detector result is claimed. The sidecar's self-contained browser snippets are schematic translations for a design panel; their focus styling and synthesized tonal ramps are preview aids, not SwiftUI runtime rules or product evidence. App Store image export and submission are separate operations.

Not canonized or repaired: no remaining defect from the scored prompt correction or selected-icon persistence fix. Unused palette/radius declarations and an unrendered custom danger-button variant are not promoted into the system. Physical Apple Intelligence latency and hardware Duo posture/gesture performance remain unverified; Simulator pose/LCD evidence does not establish those results. The Duo 3D mirror was unavailable, and new comparison/history/settings tap flows were exercised on phone and iPad rather than through that mirror.

## Analytics and marketing revision — October 20

Analytics uses native SF text styles, semantic opaque surfaces and a restrained teal Swift Charts series. Totals and the daily chart share a verified UTC window. The native date-period picker, menu breakdown and expandable daily values keep the task usable with Dynamic Type and VoiceOver.

App Store images retain measured Apple bezels and large high-contrast copy. The user removed sequence-number badges from every deck; preserve genuine numbers inside captured UI. Other Apps uses one native grouped section per app with its published icon, concise description and explicit detail/App Store destinations.

## Tip Jar — October 21

Settings → Tip Jar is a native grouped list on the adaptive opaque canvas. Keep the five named tip rows at least 44 pt high, with prices supplied by StoreKit, restrained teal price capsules and no custom checkout. At accessibility sizes, labels and prices stack and the list scrolls. The explanatory footer says tips are optional, repeatable and do not unlock features. Loading, unavailable products, purchase restrictions, retry and pending approval remain explicit. The initiating view uses SwiftUI’s scene-aware purchase action; native Back navigation remains available. No donation banners or feature gates appear in inspection flows.

Settings modal Done uses the standard confirmation-action toolbar placement. Keep native value-based destinations outside lazy list rows, and host purchase-result alerts on the sheet navigation container. The pinned Done placement exposed an iPad UIKit focus crash on Back during the 1.8 regression; preserve the verified native placement.
