# Taktung icon direction

Recorded October 11, 2026 from the user's request to consider an icon fitting the refreshed UX and color scheme. The user subsequently selected concept C, the abstract metronome, and requested a new minor release. It was initially implemented for 1.5.0 (40); build41 centers its body and base. The earlier 1.4.0 (39) submission used the copper metronome; see the release records for current review state.

## Job and constraints

The mark should suggest inspecting a release, seeing a page change and keeping evidence. It should fit adaptive neutral surfaces and restrained teal, while staying recognizable as a small Home Screen icon. Keep the name, bundle ID and App Store identity; the metronome shape and copper color are open to replacement.

Deliver a standard Xcode/Icon Composer `.icon` document with actual editable foreground layers and deliberate Default/light and Dark appearances. Preserve existing tinted/mono support. PNG renders are derived Settings/preview assets, not substitutes for layered source.

## Candidates

| Direction | Meaning | Tradeoff |
| --- | --- | --- |
| Split inspection frame — unchosen | Two page panes and one teal seam directly express before/after review. A strong outer frame gives a simple silhouette. | Needs original proportions to avoid becoming a generic split-view glyph. |
| Overlapping evidence pages | Offset page plates connect saved captures with retained Field Log evidence. | Can resemble files or notes; keep it spare and specific to inspection. |
| **Abstract metronome — selected C** | A reduced frame and single beat preserve recognition and the name's history in neutral/teal colors. | Still suggests music or timing more readily than release inspection. |

Light/dark previews of all three directions were rendered in the thread. The user chose C. The approved board is preserved in `artifacts/icon-c-1.5.0-40/approved-concepts.png`; generated study pixels are not bundled as the icon. The selected geometry was rebuilt as editable SVG parts and compiled through Xcode.

## Construction

- Use a background fill plus separate frame, pendulum and counterweight foreground layers. Do not flatten normal appearances into one image each.
- Share silhouette/geometry across appearances. Light starts from `#F5F6F8` / `#FFFFFF`, `#263237` ink and `#146B65` teal; Dark starts from `#111416` / `#1B1F22`, `#E3E9EB` ink and `#7BD6CD` teal. Selected C uses #F5F6F8 / #263237 / #146B65 in light and #111416 / #E3E9EB / #7BD6CD in dark.
- Favor broad shapes and sufficient gaps. Avoid tiny text, page prose, terminal prompts, deployment-state checkmarks, AI sparkles and borrowed Vercel marks.
- Use simple foreground vectors supported by Icon Composer. Keep the platform mask, lighting and material effects in the `.icon` settings. Preserve a clean mono silhouette.

Apple documents layers, appearance variants and Xcode integration in [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer). [App icons](https://developer.apple.com/design/human-interface-guidelines/app-icons) supplies the platform design bar.

## Current asset and implementation follow-up

`Taktung/AppIcon.icon` now contains eleven SVG sources: four Default/light parts, four Dark parts and three system-tinted foreground parts. Normal variants share geometry and retain broad readable negative spaces. Icon Composer applies the platform mask and materials; source art contains no baked rounded app tile, gloss or shadows. The previous document is preserved in `artifacts/icon-c-1.5.0-40/previous-metronome.icon`.

Apple Icon Composer ictool parses and renders Default, Dark and TintedDark variants; Xcode built and archived 1.5.0 (41) without compiler warnings. Native evidence includes 60 pt renderer previews, 52 pt Settings artwork on phone/iPad and the system-selected Dark Home Screen icon against light/dark wallpapers. `TaktungMark` was regenerated from verified renders; all three icon-bearing listing sources were refreshed for the centered build41. [Settings image provenance](settings-icon-provenance.md) and [release 1.5.0](release-1.5.0.md) record evidence and review state. Physical hardware performance is not inferred from these simulator images.

Keep the flat numbered inspection-sheet marketing format. Icon work should strengthen this identity without restarting the app's palette or navigation design.

## Centering correction, build 41

The user identified asymmetry in the build40 body/base and requested correction with a replacement review build. The frame's top, outer/inner feet, rounded shoulders and base now share x=512 on the 1024 px source canvas. Full body mirror pairs sum to 1024; the intentionally cleared right-leg region follows the unchanged angled pendulum and counterweight. Pendulum, disk, backgrounds, palette and editable layer arrangement remain the same. `.asc/qa/icon-1.5.0-41/centering-proof.json` records dimensions and preserved parts. Matching Settings renders and icon-bearing listing captures are refreshed. Current App Store state is tracked separately in the release record.
