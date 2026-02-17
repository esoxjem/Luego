# AGENTS.md

This file provides guidance for Droid instances working with the Luego codebase.

## Project Overview

**Luego** is a minimal read-it-later iOS/macOS app built with SwiftUI and Swift 5.0, targeting iOS 26.0+ and macOS. It uses SwiftData with CloudKit sync for persistence.

## Build and Test Commands

Use **XcodeBuildMCP** tools for building and testing:

### Building
```json
// Build for iOS Simulator
xcodebuildmcp___build_sim

// Build for macOS (use extraArgs)
xcodebuildmcp___build_sim with extraArgs: ["-destination", "platform=macOS"]
```

### Testing
```json
// Run all tests on iOS Simulator
xcodebuildmcp___test_sim

// Run specific test class
xcodebuildmcp___test_sim with extraArgs: ["-only-testing:LuegoTests/ArticleServiceTests"]

// Run tests on macOS
xcodebuildmcp___test_sim with extraArgs: ["-destination", "platform=macOS"]
```

### Project Discovery
```json
// List available simulators
xcodebuildmcp___list_sims

// Discover projects in workspace
xcodebuildmcp___discover_projs

// List schemes
xcodebuildmcp___list_schemes
```

### Opening the Project
```bash
open Luego.xcodeproj
```

## Architecture

### Service-Based Feature Organization

Luego uses **vertical slices by feature** with shared infrastructure:

```
Features/                    # Feature modules (vertical slices)
├── ReadingList/            # Article CRUD, list management
│   ├── Services/           # ArticleService.swift
│   └── Views/              # ArticleListView, ArticleListViewModel
├── Reader/                 # Article reading, position tracking
│   ├── Services/           # ReaderService.swift
│   └── Views/              # ReaderView, ReaderViewModel
├── Discovery/              # Random article exploration
│   ├── Services/           # DiscoveryService.swift
│   ├── DataSources/        # KagiSmallWebDataSource, BlogrollDataSource
│   └── Views/              # DiscoveryView, DiscoveryViewModel
├── Sharing/                # Share extension integration
│   ├── Services/           # SharingService.swift
│   └── DataSources/        # SharedStorage, UserDefaultsDataSource
└── Settings/               # App settings
    └── Views/              # SettingsView, SettingsViewModel

Core/                       # Shared infrastructure
├── Models/                 # SwiftData @Model classes
├── DataSources/            # Shared data access (MetadataDataSource)
├── DI/                     # DIContainer.swift
└── Configuration/          # AppConfiguration.swift

App/                        # Application entry point
├── LuegoApp.swift
└── ContentView.swift
```

### Dependency Flow

```
View → ViewModel → Service → DataSource → SwiftData
```

All services are marked with `@MainActor` because they access SwiftData's `ModelContext`. The `DIContainer` creates and wires dependencies lazily.

### Key Patterns

**Dependency Injection:**
```swift
// In LuegoApp.swift
.environment(\diContainer, diContainer)

// In Views
@Environment(\.diContainer) private var diContainer
let viewModel = diContainer.makeArticleListViewModel()
```

**Service Protocols:** All services implement protocols for testability:
- `ArticleServiceProtocol` - CRUD, favorites, archive
- `ReaderServiceProtocol` - Content fetching, position updates
- `DiscoveryServiceProtocol` - Random article fetching
- `SharingServiceProtocol` - Share extension sync

**Adding New Features:**
1. Update model in `/Core/Models/` if needed
2. Create service in `/Features/<Feature>/Services/` (mark with `@MainActor`)
3. Create ViewModel in `/Features/<Feature>/Views/`
4. Create View in `/Features/<Feature>/Views/`
5. Wire up in `DIContainer` - add service and factory method

## Data Persistence

**SwiftData with CloudKit Sync:**
```swift
ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .private("iCloud.com.esoxjem.Luego")
)
```

**Content Fetching Layer:**
1. `LuegoSDKDataSource` - Remote parsing service with caching
2. `MetadataDataSource` - Direct HTML fetching fallback
3. `ContentDataSource` - Coordinates SDK and local fallback

## Testing

Uses **Swift Testing** framework (`@Suite`, `@Test`, `#expect`).

**Test Structure:**
- `LuegoTests/Features/` mirrors `Luego/Features/`
- `LuegoTests/Core/` mirrors `Luego/Core/`
- `LuegoTests/TestSupport/Mocks/` contains mock implementations

**Mock Pattern:**
```swift
@MainActor
final class MockArticleService: ArticleServiceProtocol {
    var saveCallCount = 0
    var shouldThrowOnSave = false

    func save(_ article: Article) async throws -> Article {
        saveCallCount += 1
        if shouldThrowOnSave { throw TestError.mockError }
        return article
    }
}
```

## Platform Support

Implement features for **iOS, iPad, and macOS simultaneously**:
- Use `#if os(macOS)` / `#if os(iOS)` for platform-specific code
- macOS uses separate entitlements file (`Luego-macOS.entitlements`)
- macOS window sizing: `.defaultSize(width: 1000, height: 700)`

## Coding Guidelines

- **No inline comments** - use well-named functions instead
- **No `// MARK:`** sections - organize by abstraction level
- **SwiftUI View Organization:** Main view first, child components follow, extensions last
- **Modern patterns:** `@Observable` (not ObservableObject), `async/await`, `@MainActor`, `#Preview`

## Feature Documentation

Consult `agent_docs/` before modifying features:
- `agent_docs/discovery.md` - Discovery feature
- `agent_docs/reader.md` - Reader feature
