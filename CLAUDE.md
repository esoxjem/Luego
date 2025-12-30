# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luego** is a minimal read-it-later iOS application that allows users to save articles from URLs, fetch metadata automatically, and manage a reading list. Built with SwiftUI and Swift 5.0, targeting iOS 26.0+.

- **Supported Devices**: iPhone

## Getting Started

### Prerequisites
- Xcode 26.0 or later
- macOS with latest updates
- iOS 26.0+ SDK

### Opening the Project
```bash
open Luego.xcodeproj
```

## Development Commands

### Building with Claude Code

**IMPORTANT: Use the ios-build-fixer agent for automated building and error fixing**

Claude Code includes an `ios-build-fixer` agent that:
- Automatically checks for available iOS simulators
- Builds the project with proper error handling
- Identifies and fixes common build errors automatically
- Retries the build after applying fixes

## Project Structure

**Luego uses a service-based architecture organized by feature. See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.**

### Key Files
- **App/LuegoApp.swift**: App entry point with DIContainer initialization and environment injection
- **App/ContentView.swift**: Main article list view using ArticleListViewModel from DI
- **Core/DI/DIContainer.swift**: Manages all dependencies (services, data sources, ViewModels)
- **Core/Models/**: SwiftData models and DTOs
- **Core/DataSources/**: Shared data access (MetadataDataSource, LuegoSDK components)
- **Features/*/Services/**: Business logic operations (ArticleService, ReaderService, etc.)
- **Features/*/DataSources/**: Feature-specific data sources
- **Features/*/Views/**: ViewModels and Views using models

## Feature Documentation

**Detailed feature documentation is in `agent_docs/`**. Consult these docs before modifying a feature, and update them after making changes.

| Document | Feature |
|----------|---------|
| [agent_docs/discovery.md](agent_docs/discovery.md) | Discovery - random article exploration from Kagi Small Web and Blogroll.org |
| [agent_docs/reader.md](agent_docs/reader.md) | Reader - article reading with markdown rendering and position tracking |

These docs cover architecture, data flow, caching strategies, error handling, and file references for each feature.

## Architecture & Patterns

### Service-Based Architecture
The app follows a **service-based architecture** organized by feature with shared infrastructure:

**Organization Strategy:**
- **Features/**: Vertical slices by feature (ReadingList, Reader, Discovery, Sharing, Settings)
- **Core/**: Shared infrastructure (DI, Configuration, Models, DataSources)
- **App/**: Application entry point

**Dependency Flow**:
```
Feature Views → Feature ViewModels → Feature Services → Core DataSources
                                         ↓
                                   Core Models
```

**Architecture Principles:**
1. **Service Layer**: Business logic consolidated into cohesive services per domain
2. **Feature Cohesion**: Services and views grouped together by feature
3. **Shared Models**: SwiftData models used throughout the app
4. **Direct Model Usage**: No mapping layer between persistence and domain
5. **Protocol-Based**: Services abstracted behind protocols for testability

**Services:**
- **ArticleService**: Add, delete, update, toggle favorite/archive articles
- **ReaderService**: Fetch content, update read position
- **DiscoveryService**: Fetch random articles, cache management
- **SharingService**: Sync shared articles from share extension

**Key Benefits:**
- **Simplicity**: 3 layers (Views → ViewModels → Services) vs 4+ layers
- **Feature Locality**: All feature code in one place (services + views)
- **Testability**: Services testable with mock data sources
- **Maintainability**: Clear boundaries, related operations grouped together
- **Fewer Files**: Consolidated business logic reduces file count

### Modern Swift Features
- **@Observable**: Modern observation framework (replaces ObservableObject)
- **async/await**: All network calls use Swift concurrency
- **@MainActor**: UI updates isolated to main thread. All use cases and repositories marked with @MainActor for thread-safe SwiftData operations
- **#Preview**: Modern preview macro syntax
- **Structured Concurrency**: Task-based async operations

### State Management
- **ViewModels** use @Observable for reactive state
- **Dependency Injection**: ViewModels receive services via constructor
- **Direct Models**: Views work with SwiftData models directly
- **Services**: Business logic encapsulated in domain-focused services
- No singletons in presentation layer

### Dependency Injection Pattern
- **DIContainer**: Central dependency graph with lazy initialization
- **Environment Injection**: DI container available via SwiftUI environment
- **Constructor Injection**: All dependencies explicit in constructors
- **Factory Methods**: ViewModels created via DI container factories

**Example**:
```swift
// In LuegoApp.swift
.environment(\.diContainer, diContainer)

// In ContentView
@Environment(\.diContainer) private var diContainer
let viewModel = diContainer.makeArticleListViewModel()
```

## Dependencies

### Swift Package Manager
The project uses SwiftSPM for dependency management. Dependencies are declared in the Xcode project and resolved automatically on first build.

**Package Resolution:**
- `Package.resolved` location: `Luego.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Xcode handles dependency resolution automatically
- No manual package commands needed

## Feature Tracking

**For detailed feature status, implementation progress, and roadmap, see [FEATURES.md](FEATURES.md)**

## Development Patterns

### Adding New Features (Feature-Based Approach)
1. **Update Model** in `/Core/Models/` if needed (add properties to SwiftData model)
2. **Create/Update Service** in `/Features/<FeatureName>/Services/` with protocol and implementation (mark class with `@MainActor`)
3. **Create Data Source** in `/Core/DataSources/` or `/Features/<FeatureName>/DataSources/` if external data fetching is needed
4. **Create/Update ViewModel** in `/Features/<FeatureName>/Views/` with injected services
5. **Create View** in `/Features/<FeatureName>/Views/` using models
6. **Wire up in DIContainer** - add service and ViewModel factory methods
7. Update FEATURES.md to track implementation progress

**Important**: Always mark service classes with `@MainActor` for thread-safe SwiftData operations.

**Example**: Adding a new feature method
```
1. Core/Models/: Add property to model if needed
2. Features/ReadingList/Services/: Add method to ArticleServiceProtocol
3. Features/ReadingList/Services/: Implement method in ArticleService
4. Features/ReadingList/Views/: Call service method from ViewModel
5. Features/ReadingList/Views/: Add UI to trigger the action
```

### Coding Guidelines

**Code Clarity Over Comments:**
- **DO NOT** use inline comments to explain what code does
- **DO NOT** use `// MARK:` comments for organization
- Instead, extract well-named functions that self-document their purpose
- Function and variable names should be descriptive enough to eliminate need for comments

**Good Example:**
```swift
func extractMainContentContainer(from document: Document) -> Element? {
    let contentSelectors = ["article", "main", "[role=main]"]
    return findFirstMatchingContainer(in: document, selectors: contentSelectors)
}

func isValidContentContainer(_ container: Element) -> Bool {
    guard let text = try? container.text() else { return false }
    return text.count > 100
}
```

**Bad Example:**
```swift
// MARK: - Content Extraction

// Try to find the main content container
var contentContainer: Element?
for selector in contentSelectors {
    // Check if container has enough text (more than 100 chars)
    if let container = try? document.select(selector).first(),
       let text = try? container.text(),
       text.count > 100 {
        contentContainer = container
        break
    }
}
```

### SwiftUI View Organization

**Component Extraction:**
- Extract complex views into separate, well-named `struct` components
- Avoid deeply nested closures and view builders
- Each component should have a clear, single responsibility
- Component names should clearly describe what they display

**Top-Down Organization:**
- Main view struct appears first in the file
- Direct child views follow immediately after
- Lower-level utility views appear at the end
- Extensions and helper functions go last
- Read from top to bottom: high-level → low-level abstraction

**Good Example (Top-Down):**
```swift
struct ReaderView: View {
    var body: some View {
        Group {
            if isLoading {
                ArticleLoadingView()
            } else {
                ArticleReaderModeView(article: article)
            }
        }
    }
}

struct ArticleReaderModeView: View {
    var body: some View {
        ScrollView {
            ArticleHeaderView(title: title)
            ArticleContentView(content: content)
        }
    }
}

struct ArticleHeaderView: View {
    var body: some View {
        // Header implementation
    }
}

struct ArticleContentView: View {
    var body: some View {
        // Content implementation
    }
}

extension ReaderView {
    // Helper functions
}
```

**Bad Example (Bottom-Up):**
```swift
struct ArticleContentView: View {
    // Utility view appearing first
}

extension ReaderView {
    // Extensions before main view
}

struct ReaderView: View {
    var body: some View {
        // Main view buried at bottom
        ScrollView {
            VStack {
                // Deeply nested inline closures
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading...")
                    }
                } else {
                    // Complex inline view hierarchy
                }
            }
        }
    }
}
```

### Error Handling
- Services throw custom error types (e.g., ArticleMetadataError)
- ViewModels catch errors and store in @Observable properties
- Views display errors using alerts or inline messages

### Async Operations
- Use `async/await` for all network operations
- Wrap in `Task { }` when calling from view buttons
- Mark ViewModels with @MainActor for UI updates
- Show loading states during async work (isLoading property)

## Build Configuration

### Compiler Settings
- **Swift Version**: Swift 5.0
- **iOS Deployment Target**: 26.0
- **Swift Concurrency**: Enabled
- **Main Actor Isolation**: On by default

### Build Configurations
- **Debug**: Development builds with debugging symbols
- **Release**: Optimized builds for App Store distribution

## Testing

The project has comprehensive unit tests using Swift Testing framework (`@Suite`, `@Test`, `#expect`).

### Running Tests
- **With Claude Code**: Ask "Run the tests" - the ios-build-fixer agent handles simulator selection
- **In Xcode**: Press ⌘U
- **Command line**: `xcodebuild test -project Luego.xcodeproj -scheme Luego -destination 'platform=iOS Simulator,name=iPhone 17'`

### Test Directory Structure

Tests mirror the source structure for easy navigation:

```
LuegoTests/
├── Features/                    # Feature tests (mirrors Luego/Features/)
│   ├── ReadingList/
│   │   └── ViewModels/         # ArticleListViewModelTests
│   ├── Reader/
│   │   └── ViewModels/         # ReaderViewModelTests
│   ├── Discovery/
│   │   └── ViewModels/         # DiscoveryViewModelTests
│   └── Settings/
│       └── ViewModels/         # SettingsViewModelTests
├── Core/                        # Core tests (mirrors Luego/Core/)
│   ├── Models/                 # ArticleTests, EphemeralArticleTests, etc.
│   ├── DataSources/            # SeenItemTrackerTests, XMLSanitizerTests
│   └── UI/Readers/             # MarkdownUtilitiesTests
└── TestSupport/                 # Shared test infrastructure
    ├── Mocks/
    │   ├── Services/           # MockArticleService, MockReaderService, etc.
    │   └── DataSources/        # MockDiscoveryPreferencesDataSource, etc.
    └── Helpers/                # TestModelContainer, ArticleFixtures, etc.
```

### Test File Location Convention

Tests are located at the same relative path as their source files:
- `Luego/Features/ReadingList/Services/ArticleService.swift`
- → `LuegoTests/Features/ReadingList/Services/ArticleServiceTests.swift` (if needed)

### Adding New Tests

1. Create test file in the mirrored location under `LuegoTests/`
2. Name the file `<SourceFileName>Tests.swift`
3. Add mocks to `TestSupport/Mocks/` if needed
4. Use Swift Testing patterns:

```swift
import Testing
import Foundation
@testable import Luego

@Suite("ComponentName Tests")
@MainActor
struct ComponentNameTests {
    var mockDependency: MockDependency
    var sut: SystemUnderTest

    init() {
        mockDependency = MockDependency()
        sut = SystemUnderTest(dependency: mockDependency)
    }

    @Test("descriptive behavior")
    func testBehavior() async throws {
        #expect(result == expected)
    }
}
```

### Mock Pattern

Mocks use call tracking, argument capture, and configurable behavior:

```swift
@MainActor
final class MockArticleRepository: ArticleRepositoryProtocol {
    var saveCallCount = 0
    var shouldThrowOnSave = false
    var lastSavedArticle: Article?

    func save(_ article: Article) async throws -> Article {
        saveCallCount += 1
        if shouldThrowOnSave { throw TestError.mockError }
        lastSavedArticle = article
        return article
    }
}
```
