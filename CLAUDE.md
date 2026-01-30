# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luego** is a minimal read-it-later application that allows users to save articles from URLs, fetch metadata automatically, and manage a reading list. Built with SwiftUI and Swift 5.0, targeting iOS 26.0+ and macOS.

- **Supported Devices**: iPhone, iPad, Mac

## Development Commands

### Building and Testing

**IMPORTANT: Always use the `/xcode-test` skill for building and testing**

Run `/xcode-test` to:
- Automatically check for available iOS simulators
- Build the project with proper error handling
- Run tests on the iOS simulator
- Identify and fix common build errors automatically

### Opening the Project
```bash
open Luego.xcodeproj
```

## Architecture

**Luego uses a service-based architecture organized by feature. See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed diagrams and data flow.**

### Key Concepts

- **Features/**: Vertical slices by feature (ReadingList, Reader, Discovery, Sharing, Settings)
- **Core/**: Shared infrastructure (DI, Configuration, Models, DataSources)
- **App/**: Application entry point

**Dependency Flow**:
```
Feature Views → Feature ViewModels → Feature Services → Core DataSources
                                         ↓
                                   Core Models (SwiftData)
```

### Key Files
- **App/LuegoApp.swift**: App entry point with DIContainer and CloudKit sync initialization
- **Core/DI/DIContainer.swift**: Central dependency graph with lazy initialization
- **Core/Models/Article.swift**: Primary SwiftData model

### Services
- **ArticleService**: CRUD operations for articles (add, delete, toggle favorite/archive)
- **ReaderService**: Fetch content, update read position
- **DiscoveryService**: Fetch random articles from Kagi Small Web and Blogroll.org
- **SharingService**: Sync articles from the Share Extension

## Feature Documentation

**Detailed feature documentation is in `agent_docs/`**. Consult these docs before modifying a feature, and update them after making changes.

| Document | Feature |
|----------|---------|
| [agent_docs/discovery.md](agent_docs/discovery.md) | Discovery - random article exploration from Kagi Small Web and Blogroll.org |
| [agent_docs/reader.md](agent_docs/reader.md) | Reader - article reading with markdown rendering and position tracking |

## Data Persistence

### SwiftData with CloudKit Sync

Articles are persisted using SwiftData with automatic CloudKit sync:

```swift
ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .private("iCloud.com.esoxjem.Luego")
)
```

**Important**: All services accessing `ModelContext` must be marked with `@MainActor` for thread-safe SwiftData operations.

### Share Extension

The `LuegoShareExtension` target allows saving articles from iOS Share Sheet. Articles saved via the extension are synced to the main app through `SharingService` using shared UserDefaults (`SharedStorage`).

## Content Fetching

Article content is fetched through a layered system in `ContentDataSource`:

1. **LuegoSDK** (primary): Remote parsing service with caching
2. **Local fallback**: Direct HTML fetching via `MetadataDataSource`

The SDK is initialized asynchronously on app launch via `sdkManager.ensureSDKReady()`.

## Platform Support

### Platform Parity

Always ensure feature parity among iOS, iPad, and macOS versions:
- Implement features on all platforms simultaneously
- Use `#if os(macOS)` / `#if os(iOS)` for platform-specific code paths
- Test on all platforms before considering a feature complete

### macOS-Specific Patterns

```swift
#if os(macOS)
.defaultSize(width: 1000, height: 700)  // Window sizing
Settings { SettingsView(...) }           // macOS Settings scene
#endif
```

macOS uses a separate entitlements file (`Luego-macOS.entitlements`) for sandboxing and CloudKit.

## Development Patterns

### Adding New Features
1. **Update Model** in `/Core/Models/` if needed
2. **Create/Update Service** in `/Features/<FeatureName>/Services/` (mark with `@MainActor`)
3. **Create/Update ViewModel** in `/Features/<FeatureName>/Views/`
4. **Create View** in `/Features/<FeatureName>/Views/`
5. **Wire up in DIContainer** - add service and ViewModel factory methods

### Dependency Injection

```swift
// In LuegoApp.swift
.environment(\.diContainer, diContainer)

// In Views
@Environment(\.diContainer) private var diContainer
let viewModel = diContainer.makeArticleListViewModel()
```

### Coding Guidelines

**Code Clarity Over Comments:**
- **DO NOT** use inline comments or `// MARK:` for organization
- Extract well-named functions that self-document their purpose

**SwiftUI View Organization (Top-Down):**
- Main view struct appears first
- Child components follow in order of abstraction
- Extensions and helpers go last

### Modern Swift Patterns
- **@Observable**: Modern observation framework (not ObservableObject)
- **async/await**: All network calls use Swift concurrency
- **@MainActor**: Required for all services using ModelContext
- **#Preview**: Modern preview macro syntax

## Testing

The project uses Swift Testing framework (`@Suite`, `@Test`, `#expect`).

### Running Tests
- **With Claude Code**: Run `/xcode-test`
- **In Xcode**: Press ⌘U
- **Command line**: `xcodebuild test -project Luego.xcodeproj -scheme Luego -destination 'platform=iOS Simulator,name=iPhone 17'`

### Test Structure

Tests mirror source structure under `LuegoTests/`:
- `LuegoTests/Features/` mirrors `Luego/Features/`
- `LuegoTests/Core/` mirrors `Luego/Core/`
- `LuegoTests/TestSupport/Mocks/` contains mock implementations

### Mock Pattern

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

## Dependencies

Swift Package Manager dependencies are declared in the Xcode project and resolved automatically. Package.resolved is at:
`Luego.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
