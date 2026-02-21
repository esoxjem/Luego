# AGENTS.md

Working agreement for agents in the Luego repository.

## Operating Model

- Keep the main agent focused on requirements, key decisions, and final outputs.
- Use specialized sub-agents in parallel for exploration, implementation, testing, and analysis.
- Return concise sub-agent summaries instead of raw intermediate logs.

## Skills Available

- [$axiom-cloud-sync](/Users/arunsasidharan/.agents/skills/axiom-cloud-sync/SKILL.md): CloudKit vs iCloud Drive decisions, offline-first sync architecture.
- [$axiom-cloud-sync-diag](/Users/arunsasidharan/.agents/skills/axiom-cloud-sync-diag/SKILL.md): Systematic diagnostics for CloudKit and iCloud Drive sync failures.
- [$axiom-cloudkit-ref](/Users/arunsasidharan/.agents/skills/axiom-cloudkit-ref/SKILL.md): CloudKit APIs and modern patterns, including CKSyncEngine and conflict handling.

## Project Snapshot

- Product: Luego, a minimal read-it-later app.
- Stack: SwiftUI + Swift 5.0.
- Platforms: iOS 26.0+, iPadOS 26.0+, macOS 15.0+.
- Persistence: SwiftData + CloudKit private database.
- CloudKit container: `iCloud.com.esoxjem.Luego`.
- Extra target: `LuegoShareExtension/` for share-sheet ingestion.

## First Run Setup

Run the repository setup step before the first build:

```bash
ln -sf "$CONDUCTOR_ROOT_PATH/Luego/Core/Configuration/Secrets.swift" ./Luego/Core/Configuration/Secrets.swift
```

Then open the project:

```bash
open Luego.xcodeproj
```

## Build And Test

Use XcodeBuildMCP wrappers when available.

```bash
xcodebuildmcp___build_sim
xcodebuildmcp___build_macos
xcodebuildmcp___test_sim
xcodebuildmcp___test_macos
xcodebuildmcp___list_sims
xcodebuildmcp___discover_projs
xcodebuildmcp___list_schemes
```

Fallback raw `xcodebuild` commands:

```bash
xcodebuild -project Luego.xcodeproj -scheme Luego -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" build
xcodebuild -project Luego.xcodeproj -scheme Luego -configuration Debug -destination "platform=macOS" build
xcodebuild test -project Luego.xcodeproj -scheme Luego -destination "platform=iOS Simulator,name=iPhone 17,OS=latest"
xcodebuild test -project Luego.xcodeproj -scheme Luego -destination "platform=macOS"
```

Run a specific test target/class:

```bash
xcodebuild test -project Luego.xcodeproj -scheme Luego -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" -only-testing:LuegoTests/Features/ReadingList/Services/ArticleServiceTests
```

## Repository Map

- `Luego/App/`: app entry and root navigation.
- `Luego/Core/`: shared infrastructure (`Configuration`, `DI`, `Models`, `DataSources`, UI helpers).
- `Luego/Features/`: vertical feature slices (`ReadingList`, `Reader`, `Discovery`, `Sharing`, `Settings`).
- `LuegoShareExtension/`: macOS/iOS share extension target.
- `LuegoTests/`: mirrors app structure (`Core`, `Features`, `Integration`, `TestSupport/Mocks`).
- `agent_docs/`: focused feature docs (`discovery.md`, `reader.md`).
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

## Testing Rules

- Framework: Swift Testing (`@Suite`, `@Test`, `#expect`).
- Mirror production structure in tests.
- Prefer deterministic unit tests over broad integration tests unless behavior spans layers.
- Reuse or extend mocks in `LuegoTests/TestSupport/Mocks/`.
- For new services/view models, add tests in the matching feature subtree.

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

## Before Merging

1. Build for simulator and macOS.
2. Run relevant test suites (or full tests when changes are cross-cutting).
3. Check `agent_docs/` and `docs/prevention/` for regressions in known risky areas.
