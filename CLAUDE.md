# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luego** is a minimal read-it-later iOS application that allows users to save articles from URLs, fetch metadata automatically, and manage a reading list. Built with SwiftUI and Swift 5.0, targeting iOS 26.0+.

- **Supported Devices**: iPhone and iPad (Universal)
- **Current Version**: 1.0 (Build 1) - v0.1.0 Alpha (in active development)

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

**Luego follows Clean Architecture principles organized by feature. See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.**

### Key Files
- **App/LuegoApp.swift**: App entry point with DIContainer initialization and environment injection
- **App/ContentView.swift**: Main article list view using ArticleListViewModel from DI
- **Core/DI/DIContainer.swift**: Manages all dependencies (repositories, use cases, ViewModels)
- **Core/Models/**: SwiftData models and DTOs
- **Features/*/UseCases/**: Business logic operations (testable, minimal framework dependencies)
- **Features/*/Repositories/**: Repository protocols and implementations
- **Features/*/Views/**: ViewModels and Views using models

## Architecture & Patterns

### Pragmatic Architecture
The app follows a **pragmatic architecture** organized by feature with shared infrastructure:

**Organization Strategy:**
- **Features/**: Vertical slices by feature (ArticleManagement, Reader, Sharing)
- **Core/**: Shared infrastructure (DI, Configuration, Models, DataSources)
- **App/**: Application entry point

**Dependency Flow**:
```
Feature Views → Feature UseCases → Feature Repositories → Core Models
                    ↓
            Core DataSources
```

**Architecture Principles:**
1. **Feature Cohesion**: Related use cases and views grouped together
2. **Shared Models**: SwiftData models used throughout the app
3. **Direct Model Usage**: No mapping layer between persistence and domain
4. **Repository Pattern**: Data access abstracted behind protocols

**Key Benefits:**
- **Feature Locality**: All feature code in one place (use cases + views)
- **Testability**: Use cases testable with mock repositories
- **Maintainability**: Clear boundaries, single responsibility
- **Simplicity**: No boilerplate mapping code
- **Scalability**: Easy to add features, understand scope

### Modern Swift Features
- **@Observable**: Modern observation framework (replaces ObservableObject)
- **async/await**: All network calls use Swift concurrency
- **@MainActor**: UI updates isolated to main thread
- **#Preview**: Modern preview macro syntax
- **Structured Concurrency**: Task-based async operations

### State Management
- **ViewModels** use @Observable for reactive state
- **Dependency Injection**: ViewModels receive dependencies via constructor
- **Direct Models**: Views work with SwiftData models directly
- **Use Cases**: Business logic encapsulated in single-purpose use cases
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
2. **Create/Update Repository** in `/Features/<FeatureName>/Repositories/` with protocol and implementation
3. **Create Use Case** in `/Features/<FeatureName>/UseCases/` for business logic
4. **Create Data Source** in `/Core/DataSources/` or `/Features/<FeatureName>/DataSources/` if needed
5. **Create/Update ViewModel** in `/Features/<FeatureName>/Views/` with injected use cases
6. **Create View** in `/Features/<FeatureName>/Views/` using models
7. **Wire up in DIContainer** - add repository, use case, and ViewModel factory methods
8. Update FEATURES.md to track implementation progress

**Example**: Adding "Favorite Articles" feature
```
1. Core/Models/: Add `isFavorite: Bool` to Article model
2. Features/ArticleManagement/Repositories/: Add `toggleFavorite(id:)` to ArticleRepositoryProtocol
3. Features/ArticleManagement/UseCases/: Create ToggleFavoriteUseCase.swift
4. Features/ArticleManagement/Repositories/: Implement `toggleFavorite` in ArticleRepository
5. Core/DI/: Add toggleFavoriteUseCase to DIContainer
6. Features/ArticleManagement/Views/: Use case in ArticleListViewModel
7. Features/ArticleManagement/Views/: Add favorite button to ArticleRowView
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

Currently, no test targets are configured. When adding tests:
1. Create a test target via Xcode: File → New → Target → Unit Testing Bundle
2. Add test files with `XCTestCase` subclasses
3. Run tests:
   - **With Claude Code**: Ask "Run the tests" - the ios-build-fixer agent will handle simulator selection and test execution
   - **In Xcode**: Press ⌘U
   - **Manual command line**: `xcodebuild test -project Luego.xcodeproj -scheme Luego -destination 'platform=iOS Simulator,name=<SIMULATOR_NAME>'`
     (Check available simulators first using `xcrun simctl list devices available | grep "iPhone"`)

**Recommended Test Coverage:**
- ArticleMetadataService: URL validation, HTML parsing, error handling
- ArticleListViewModel: Add/delete operations, state management
- Article model: Codable conformance, domain computation
