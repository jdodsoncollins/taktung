# Field log design

The field log is the accepted direction for Activity. It follows familiar activity-log and developer-tool interactions, expressed through Taktung's copper workbench language. This design contract is implemented in 1.3.0 (36) using native SwiftUI List sections, search, menus and sheets. `Domain/FieldLog.swift` supplies tested scope/filter/search composition and local-calendar grouping.

Its job is to answer three questions: what happened, which site or deployment it concerned, and what evidence was recorded. It records actions and observations on this device. It does not imply a complete account-wide Vercel audit trail.

## Familiar behavior, original composition

| Established pattern | Taktung's variation |
|---|---|
| Chronological activity list | Newest first, grouped into Today, Yesterday, and dated sections. A restrained copper rail aligns time and event markers. |
| Consistent event hierarchy | Lead with the event or note, then its subject and concise evidence. Exact timestamps and full identifiers remain available in detail. |
| Event types and outcomes | A small symbol and readable text distinguish a note, comparison, check, and deployment action. Failure or cancellation is stated explicitly. |
| Search and scoped filters | Native search plus visible site scope and active filter state. All-sites mode adds the site name to each relevant row. |
| Progressive disclosure | Tapping a row opens the full saved entry. Secondary actions and retention information move into clearly labeled menus or disclosures. |
| Developer provenance | Deployment IDs and stored capture provenance identify the evidence. Menlo is reserved for technical fields; prose uses system type. |
| Stable reading position | Receiving new activity preserves the reader's position. A visible new-entry affordance can return them to the newest records. |
| Native platform behavior | Familiar navigation, menus, search, sheets, focus behavior, and destructive confirmation, with opaque content surfaces. |

The rail is an alignment device, not a Git branch graph: it must not imply causality or relationships absent from the stored data. Taktung's identity comes from the relationship between page inspection, technical evidence, and personal notes, together with its own spacing, typography, and palette.

## Row anatomy

Each event has a consistent reading order:

1. Event or note title, with the time nearby.
2. Site/deployment context when it is needed to disambiguate the row.
3. A brief saved observation or a note excerpt.
4. An explicit outcome when it adds meaning, especially failure, cancellation, or an action still awaiting confirmation.

Notes use an understated note symbol and readable prose. Routine successful checks do not need a large repeated SUCCESS heading. Text must still identify the event type, and essential outcomes must remain understandable without color or icons.

On compact screens, time and metadata can move below the title. Large Dynamic Type stacks the row rather than compressing or truncating essential context. An entire row remains a clear navigation target; controls embedded in a row must have their own distinguishable labels.

Do not fabricate actor names or server event times. `ActivityItem.createdAt` is the local journal timestamp. A successful capture is not a passed regression test; mutation acceptance is not READY. Display only the state and evidence actually recorded.

## Filters and details

- Keep the Activity tab name and selected-site header familiar. A small Field log heading can identify the content without introducing a new navigation model.
- Search, site scope, and event filters combine predictably. Applied filters stay visible, with a way to reset them.
- Distinguish empty history from no filter matches and from a storage failure. Resetting filters never clears stored history.
- Add note is the main creation action. Export uses the currently displayed records. Clear activity stays secondary and retains the existing confirmation and team scope.
- Detail preserves complete saved text, the absolute timestamp, available identifiers, and export. Navigation back preserves filters and reading context.
- Opening or filtering the journal does not issue deployment fetches. It uses persisted records already available to the session.

The first implementation can use existing `ActivityItem` fields. Structured evidence fields should be added before introducing richer provenance displays that cannot be represented reliably by those fields. Historical image previews require the exact event's retained capture; the latest baseline cannot represent an older event.

## Accessibility and originality

[Apple's disclosure guidance](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls) supports keeping common tasks visible and revealing advanced detail when relevant. [Primer's timeline accessibility guidance](https://primer.style/product/components/timeline/accessibility/) reinforces orderly events, manageable descriptions, consistent markers, and text alternatives. These inform behavior and usability; no product's component layout, assets, or style tokens are being copied.

Use native SwiftUI controls and explicit accessibility grouping. Reading order should communicate event, context, outcome, and time. Decorative rail segments are hidden from accessibility. Text must retain sufficient contrast, respond to Dynamic Type, and wrap without horizontal scrolling. Custom controls need at least a 44-point target. Motion must respect Reduce Motion.

Evaluate the result on compact iPhone, Duo inner and outer displays, and large text. Test a mixed timeline of notes, checks, captures, accepted actions, confirmed outcomes, failures, and account-level entries. Also check active filters, no matches, empty history, storage errors, and returning from detail.

The originality test is whether the content hierarchy still works without the copper styling, and whether the finished styling remains recognizable as Taktung. Familiar interactions and an original composition must both hold.

## Implementation validation — 1.3.0

Five domain tests cover combined filters, important/issues selection, deterministic ordering and local day boundaries including DST. Note retry recovery has a separate filesystem-failure regression. Native checks verified note creation, full detail, Notes/Important filters, restart persistence and the new-entry button while reading older entries. The button reveals newly received records without jumping the older viewport. Large Dynamic Type stacks row content and filters; the largest system size was smoke checked on the Duo cover. This is not a complete VoiceOver certification. See [release evidence](release-1.3.0.md).
