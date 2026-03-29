---
name: macos-deploy
description: Unified macOS release execution and hardening for Luego. Use when building or publishing macOS releases, resolving Sparkle signing/key mismatches, reviewing appcast/notarization reliability, validating runtime updater behavior, or changing macOS release workflow/configuration files such as `Configuration/Info-macOS.plist`, `Configuration/Luego-*.xcconfig`, `Luego/Core/Updates/AppUpdateController.swift`, or `Luego/App/LuegoApp.swift`.
---

# macos-deploy

Execute and validate the full Luego macOS release path, including Sparkle safety and runtime behavior checks.

## Required references

- `references/release-workflow.md`
- `references/sparkle-release-checklist.md`
- `references/runtime-update-validation.md`

Read all references before proposing changes or running release commands.

## Workflow

1. Decide mode.
   - Use release mode when shipping a macOS build.
   - Use audit mode when reviewing CI, Sparkle, or runtime updater behavior.
2. Run preflight checks.
   - Confirm versioning intent.
   - Confirm Sparkle keys/feed configuration (`SUFeedURL`, `SUPublicEDKey`).
   - Confirm Sparkle private key material resolves to the same public key used in app config.
   - Confirm signing and notarization credentials are available.
   - If a dedicated CI release workflow is expected, confirm the workflow file path that exists in this checkout before treating its absence as a finding.
3. Execute release mode from `references/release-workflow.md` when publishing.
4. Execute audit mode from `references/sparkle-release-checklist.md` and `references/runtime-update-validation.md` when reviewing.
5. Report outcome.
   - For release mode, return produced artifacts, tag/release URL, and validation commands executed.
   - For audit mode, report P1/P2/P3 findings with exact file evidence and minimal remediation.

## Non-negotiable rules

- Require signed Release builds for publication.
- Require notarization submit, successful wait, stapling, and Gatekeeper assessment before publishing.
- Resolve `generate_appcast` deterministically from explicit job `-derivedDataPath`.
- Fail when appcast tool discovery returns zero or multiple candidates.
- Detect and remediate ad-hoc signatures inside `Sparkle.framework` helpers before notarization.
- Keep appcast signing key and app `SUPublicEDKey` aligned before publishing.
- Keep Debug/test runs from initializing Sparkle updater.
- Keep Debug UI from exposing `Check for Updates…`.
