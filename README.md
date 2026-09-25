# Taktung

**Taktung** (German: *putting work on a beat*) is a local-first **Vercel
operations assistant**. This repository is the **native SwiftUI** port of
the Expo Takt app. The App Store name is Taktung because Takt is already
used by other apps. Bundle ID and URL scheme match Takt:
`com.jcollins.takt` / `takt://`.

> Show me what changed, explain what broke, and prepare the safest next action.

This is **not** a full Vercel dashboard clone. It is a mobile control plane
for incident, deployment, and configuration intelligence — with hard
confirmation for mutators and honest success/failure in Activity.

Source is [MIT](LICENSE).

---

## Features

| Area | What you get |
|------|----------------|
| **Home / projects** | Selected **site** briefing, production state, needs-attention. Header switches sites on every tab |
| **Deployments** | List + detail. Redeploy / promote / rollback stay hard-confirm actions |
| **Incident summary** | Deterministic diagnosis from logs, env presence, last success |
| **Env drift** | Names and targets only — **never secret values** |
| **READY poll** | After mutators, Activity records READY only when Vercel confirms |
| **Auth** | Personal access token (Keychain). OAuth PKCE when a client ID is configured |
| **Demo** | Screenshot fixture path. Off unless `TAKT_DEMO_MODE` is set. Never mixed with live Vercel |
| **Search** | On-device lookup when Apple Intelligence is available; heuristic otherwise. Visible in demo for screenshots |
| **UI** | SwiftUI, iOS 27, Liquid Glass chrome, opaque iron/copper content |

### Safety rules

- Env variable **values** never enter the UI, Activity, or ops brief
- No arbitrary shell or free-form API from model output
- Typed, allow-listed actions only
- Hard confirmation for redeploy, promote, rollback
- Deployment success is only claimed when Vercel reports **READY**

### Control plane

```text
Vercel adapter
  → normalized resources
  → typed action plans
  → local analysis
  → review / hard confirm
  → confirmed execution
  → activity / audit history
```

---

## App structure

```text
taktung/
├── Taktung.xcodeproj
├── Taktung/
│   ├── TaktungApp.swift
│   ├── Domain/           # Pure logic (no SwiftUI / network)
│   ├── Services/         # Vercel REST, Keychain, demo client
│   ├── Shell/            # AppSession orchestration
│   ├── Features/         # Screens / sheets
│   ├── DesignSystem/     # Copper rack tokens
│   └── Support/          # Demo fixtures, accessibility IDs
├── TaktungTests/
└── docs/
```

---

## Requirements

- **Xcode 27** (iOS 27 SDK)
- **iOS 27.0+**
- Apple Developer team for device/store builds (simulator works unsigned
  with Automatic signing)

## Build and run

```bash
open Taktung.xcodeproj
```

Or from the command line:

```bash
xcodebuild -scheme Taktung -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=27.0' build
```

### Demo mode (screenshots)

Launch with `TAKT_DEMO_MODE=1` or enable **Screenshot demo** in Settings.
Fixtures never mix with a live token.

```bash
xcrun simctl launch booted com.jcollins.takt -TAKT_DEMO_MODE
```

The **Taktung Demo** scheme sets this for you.

### Personal access token

Create a token at [vercel.com/account/tokens](https://vercel.com/account/tokens).
Paste it in Settings. It is stored in the Keychain on this device only.

For UI tests you may pass `TAKT_UI_TOKEN` as a process environment variable.
Do not commit tokens.

### Tests

```bash
xcodebuild -scheme Taktung -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' test
```

### TestFlight

Store builds reuse the existing Takt EAS project and App Store app. The marketing version must be higher than the live App Store version.

```bash
npx eas-cli build -p ios -e testflight --local --output .asc/artifacts/Taktung.ipa --non-interactive
npx eas-cli submit -p ios -e testflight --path .asc/artifacts/Taktung.ipa --non-interactive --wait
```

---

## Sister apps

- [takt](https://github.com/jdodsoncollins/takt) — Expo / React Native original
- [MobileflowRN](https://github.com/jdodsoncollins/MobileflowRN) — Webflow ops (separate product)

Keep the codebases separate.
