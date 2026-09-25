# Security Policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use GitHub private vulnerability reporting. Include the affected version, reproduction steps, impact, and any suggested mitigation.

You should receive an initial response within 7 days.

## Scope

Reports may cover the iOS app, Keychain token storage, Vercel action confirmation, or the on-device brief. Reports about Vercel or Apple infrastructure should go to those vendors.

Never include access tokens, environment values, or private project data in a report.

## Handling secrets

- Personal access tokens stay in the Keychain. A debug-only `TAKT_UI_TOKEN` environment variable is for local UI tests and is not read in Release.
- Environment variable values are not rendered, logged, or sent to the on-device model.
