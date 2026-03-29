# Runtime update validation

## Scope

Validate Sparkle runtime integration in:
- `Luego/Core/Updates/AppUpdateController.swift`
- `Luego/App/LuegoApp.swift`

## Required checks

1. Platform boundary
   - Ensure Sparkle import and updater wiring are macOS-only.
   - Ensure iOS/iPadOS paths are unaffected.

2. Debug/test suppression
   - Ensure Debug and test execution paths do not initialize Sparkle updater.
   - Ensure Debug does not expose `Check for Updates…` command.

3. Release behavior
   - Ensure Release/Beta expose expected update UX and updater behavior.
   - Ensure command action routes to updater call path.

4. Startup behavior
   - Detect eager updater initialization at app launch.
   - If eager startup is retained, require explicit justification or measurement note.

5. Testability/architecture seam
   - Check whether updater is directly instantiated in app composition root.
   - Prefer protocol seam or replaceable abstraction when runtime behavior must vary in tests.

6. Agent parity
   - Detect UI-only update actions with no automation-equivalent path.
   - Record accepted exception or add parity task.

## Evidence format

For each finding:
- Severity: `P1`, `P2`, or `P3`
- File + lines
- Quoted snippet
- Why it matters
- Minimal remediation

## Baseline expectations for Luego

- Debug: updater not initialized, update menu hidden.
- Release/Beta: updater available per policy.
- App config includes `SUFeedURL` and `SUPublicEDKey` for macOS builds.
