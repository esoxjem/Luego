# AGENTS.md

## Project Snapshot

- Product: Luego, a minimal read-it-later app.
- Stack: SwiftUI + Swift 5.0.
- Platforms: iOS 26.0+, iPadOS 26.0+, macOS 15.0+.
- Persistence: SwiftData + CloudKit private database.
- CloudKit container: `iCloud.com.esoxjem.Luego`.
- Extra target: `LuegoShareExtension/` for share-sheet ingestion.

## Repository Map

- `Luego/App/`: app entry and root navigation.
- `Luego/Core/`: shared infrastructure (`Configuration`, `DI`, `Models`, `DataSources`, UI helpers).
- `Luego/Features/`: vertical feature slices (`ReadingList`, `Reader`, `Discovery`, `Sharing`, `Settings`).
- `LuegoShareExtension/`: macOS/iOS share extension target.
- `docs/prevention/`: known pitfalls and prevention playbooks.

## Architecture Rules

- Keep this dependency flow: `View -> ViewModel -> Service -> DataSource -> SwiftData`.
- Services touching `ModelContext` must be `@MainActor`.
- Every service should have a protocol for testability.
- Wire dependencies only through `DIContainer`.
- When adding a feature:

1. Add/update model in `Luego/Core/Models/` if required.
2. Add service in `Luego/Features/<Feature>/Services/`.
3. Add view model and views in `Luego/Features/<Feature>/Views/`.
4. Register factories in `Luego/Core/DI/DIContainer.swift`.

## Data And Sync Rules

- Use SwiftData with CloudKit private DB in app configuration.
- Keep content fetch layering intact:

1. `LuegoSDKDataSource` for primary parsing/caching.
2. `MetadataDataSource` as fallback.
3. `ContentDataSource` as coordinator.

- Preserve offline-first behavior and avoid blocking the main thread during sync-sensitive flows.

## Verification Rules

- Never use raw `xcodebuild`; always use the `xcodebuildmcp` CLI (via `scripts/xcodebuildmcp-luego` when working in this repo) for simulator and macOS builds.
- Do not add or reference the deleted automated test suite in repository automation or maintenance docs.

## Platform Rules

- Implement and verify changes for iOS, iPadOS, and macOS together.
- Use platform guards (`#if os(iOS)`, `#if os(macOS)`) only where behavior truly differs.
- Keep entitlements in sync with target capabilities:
  - `Luego/Luego.entitlements`
  - `Luego/Luego-macOS.entitlements`
  - `LuegoShareExtension/LuegoShareExtension.entitlements`

## Coding Rules

- No inline comments.
- No `// MARK:` sections.
- Prefer clear naming and small functions over commentary.
- Use modern Swift patterns: `@Observable`, `async/await`, `@MainActor`, `#Preview`.
- SwiftUI organization: root view first, supporting subviews next, extensions last.
- Prefer Deep Modules and Deep Classes

## Verification

1. Build for simulator and macOS.
2. Check `agent_docs/` and `docs/prevention/` for regressions in known risky areas.
3. Run the app via xodebuildmcp cli and verify with logs or screenshots.