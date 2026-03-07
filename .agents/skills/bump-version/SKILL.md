---
name: bump-version
description: CalVer version and build-number update workflow for Luego. Use when preparing TestFlight or macOS releases, fixing duplicate build-number uploads, or synchronizing `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` across all targets in `Luego.xcodeproj/project.pbxproj`.
---

# bump-version

Update Luego version metadata consistently for app, share extension, and tests.

## Versioning policy

- Use CalVer format `YYYY.MM.DD` for `MARKETING_VERSION`.
- Use integer build number for `CURRENT_PROJECT_VERSION`.
- Keep all targets in sync.

## Workflow

1. Read current values:
   ```bash
   grep -E "MARKETING_VERSION|CURRENT_PROJECT_VERSION" Luego.xcodeproj/project.pbxproj | head -12
   ```
2. Choose update mode.
   - Build-only: increment `CURRENT_PROJECT_VERSION`.
   - New version: set `MARKETING_VERSION` to `YYYY.MM.DD`, reset build number to `1`.
3. Edit all occurrences in `Luego.xcodeproj/project.pbxproj` for:
   - `Luego`
   - `LuegoShareExtension`
   - `LuegoTests`
4. Verify updated values and consistency across Debug/Release entries.
5. Stage and commit:
   - `git add Luego.xcodeproj/project.pbxproj`
   - `git commit -m "bump version"`
   - `git commit -m "bump version to YYYY.MM.DD"` when version date changes.

## Guardrails

- Do not leave mixed versions between targets.
- Do not change version format away from `YYYY.MM.DD`.
- Prefer build-only increment for same-day reuploads.

## Output contract

- Return previous and new version/build values.
- Return count of updated `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` lines.
- Return commit hash if a commit was created.
