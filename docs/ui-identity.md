# Taktung UI identity

Historical 1.3.0 exploration. The copper recommendation below is superseded by the neutral/teal 1.4.0 system in [DESIGN.md](../DESIGN.md). Current product commitments are in [PRODUCT.md](../PRODUCT.md); the user's icon follow-up is recorded in [icon direction](icon-direction.md). Retain this document as context, not current palette or icon authority.

Direction based on the current app and its native simulator screenshots. The Field Log is implemented in 1.3.0 (36), following the [design contract](field-log-design.md). Native daily sections, readable notes, visible filters and stable reading position establish its developer-tool conventions. The further Home and Compare composition changes below remain proposals.

Taktung should feel like a compact workbench for inspecting a release. The copper palette is already recognizable. Its next source of identity should be the way it presents page evidence, comparisons, and the record of decisions.

## Reference

The accessible portion of [How to turn your AI into a world-class designer](https://www.lennysnewsletter.com/p/how-to-turn-your-ai-into-a-world) recommends exploring distinct concepts, developing one coherent identity, using screenshot criticism, and removing unnecessary elements. The final section is paywalled. The Taktung recommendations below are an application of those ideas to this repository, rather than claims from the article.

## Assessment before the Field Log implementation

The iron canvas, copper accent, mint READY state, and monospaced identifiers already establish a visual vocabulary. Native navigation provides a familiar frame around it.

The composition is less distinctive. Home centers a small page image in a large bordered panel and places several full-width actions below it. Compare repeats the deployment overview before the actual comparison on compact displays. History dedicates a substantial area to controls and repeats outcome words, site names, and timestamps above text entries. These screens share colors but do not yet share a memorable way of presenting evidence.

Sources inspected: `HomeView`, `Components`, `ActivityView`, the current comparison layout, the Home store screenshot, and the history/comparison simulator captures.

## Directions considered

| Direction | Defining composition | Fit |
|---|---|---|
| Release proof sheet | Page captures arranged like proofs, with commit and route captions attached to each image. | Makes visual review the strongest feature. Dense grids need care on compact screens. |
| Engineering field log | A quiet chronological record, with notes and actions as distinct entry types and dates as section headers. | Gives persistent history an identity. It is a supporting language for the review flow. |
| Copper workbench | A large inspection surface, a narrow metadata rail, and restrained controls. Comparison is the signature interaction. | Recommended. It develops the existing copper direction and fits Duo's two panes. |

## Recommended language

Use the workbench for Home and Compare, with a field log for Activity. The recurring pattern is a page under inspection, its identifying evidence attached to it, and a record of what happened.

- Retain the existing iron/copper/mint palette. Copper denotes an active tool or deliberate action; mint denotes a confirmed state.
- Let real site captures supply visual variety. Generated artwork is unnecessary in an evidence tool and must not stand in for a live page.
- Use system type for titles and reading. Reserve Menlo for commits, routes, states, and times.
- Prefer dividers and alignment to a border around every group. Use opaque surfaces for the page stage and content, with Liquid Glass confined to native navigation chrome.
- Use a consistent, thin copper divider as the comparison handle. Its motion must correspond to the user's drag, with a native accessible slider and reduced-motion support.
- Keep native tabs, sheets, menus, search, and destructive confirmations. Identity comes from content composition and the inspection interaction.

## First layout changes

### Compare

Make the comparison image the primary content immediately after a compact deployment heading. While Compare is selected, remove the redundant thumbnail overview. Keep route/reference selection nearby, with a single capture action; place viewport limitations in an information disclosure rather than permanent prose competing with the images.

Attach baseline and candidate commit/time captions directly to their respective images. Keep Expand and Save baseline as secondary tools. Saving remains explicit, and comparing does not imply approval or promotion.

On Duo, place baseline and candidate in separate usable regions when their size allows it. Keep controls and provenance within those regions and clear of the division. Preserve the existing state across layout changes. On compact iPhone, prioritize the reveal view and scrolling review.

### Activity: field log

Follow the [field log design contract](field-log-design.md). The interaction model uses standard activity-log conventions; Taktung supplies an original composition and visual language. Chronology, provenance, search, readable event types, and accessibility take precedence over decorative novelty.

Group entries by day. Lead with the event or note; demote repeated SUCCESS/INFO labels and the selected site's repeated name. Keep failures explicit through text and color. Distinguish notes with typography and a note icon rather than another card color.

Keep search in native chrome. Put filter options together and move Clear activity into an overflow menu with the existing confirmation. Add note should be the obvious creation action; storage and retention details belong in an information disclosure.

The first pass can use existing records. Historical image thumbnails require retaining the image for that exact event; the latest saved baseline must never be presented as an older capture.

### Home

Give the production face a better-sized inspection surface with commit, branch, age, and status attached to its edge. Reduce unused space inside the preview panel. Retain Diagnose as the main check, and present environment drift and failed-build diagnosis as quieter secondary actions.

Do not add a general dashboard, extra metrics, or cross-project deployment requests to fill space. The selected site's production face remains the primary job.

## How to judge the result

Start with compact Compare and Activity, then adapt the same composition to Duo. Review the same real screenshots before and after each pass, using consistent states and content. Limit the first critique cycle to two iterations.

The review should establish whether:

1. The page under inspection and the selected route are immediately clear.
2. Baseline and candidate provenance can be read without opening another screen.
3. Compare and Activity look related without every section using the same card.
4. The app remains recognizable when the site capture is removed.
5. Loading, protected pages, failed storage, and empty history receive as much attention as successful screenshots.
6. Large Dynamic Type, VoiceOver, reduced motion, and all Duo arrangements remain usable.

Any criticism must name the visible element and the change it needs. A numerical taste score alone is not evidence of improvement.
