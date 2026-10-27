# Settings image provenance

For 1.5.0 (41), `TaktungMark` uses verified Default/light and Dark renders of the user-selected C abstract metronome from `Taktung/AppIcon.icon`. Apple Icon Composer's `ictool` generated the 1024 px iOS 27 renders in `.asc/qa/icon-1.5.0-41/light.png` and `dark.png`. The asset catalog receives their unmodified pixels plus embedded origin metadata. The `.icon` source contains separate editable background, frame, pendulum and counterweight SVG parts for each normal appearance; the tinted group has three separate foreground parts.

Settings chooses artwork through the resolved in-app appearance, including forced Light/Dark. Home Screen appearance remains system-owned. Native compact iPhone and iPad Settings captures verify the centered selected C in both Light/Dark appearances; the installed Home Screen Dark glyph and Apple-processed build41 icon were also inspected. The large phone listing Settings poster uses the genuine compact capture with source aspect preserved. Default/light was verified through Apple's renderer and native light Settings. See [icon direction](icon-direction.md).

`CodableMark` is the official App Store artwork for the developer’s Codable app, app ID 1324741659. Source: https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/5d/31/c6/5d31c6ba-6990-d6e7-c1e6-4edc3f79666b/AppIcon-0-0-1x_U007epad-0-1-85-220.png/512x512bb.jpg
Listing: https://apps.apple.com/us/app/codable/id1324741659
Downloaded October 11, 2026. The image is bundled for offline Settings; no listing fetch occurs in the product.
