# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Luego** is a minimal read-it-later iOS application that allows users to save articles from URLs, fetch metadata automatically, and manage a reading list. Built with SwiftUI and Swift 5.0, targeting iOS 26.0+.

- **Bundle ID**: com.esoxjem.Luego
- **Development Team**: QTZUF46V7A
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

### Building
- **Build**: ⌘B in Xcode, or `xcodebuild -project Luego.xcodeproj -scheme Luego -configuration Debug build`
- **Run**: ⌘R in Xcode to build and run on simulator or connected device
- **Clean**: ⌘⇧K in Xcode, or `xcodebuild clean -project Luego.xcodeproj -scheme Luego`

### Running on Specific Simulators
**IMPORTANT: Always check available simulators before building**

```bash
# List available iPhone simulators
xcrun simctl list devices available | grep "iPhone"

# Build and run on specific simulator (use a simulator from the list above)
xcodebuild -project Luego.xcodeproj -scheme Luego -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Note:** Simulator names vary by Xcode version. Always check available simulators first and use an exact name from the list.

## Project Structure

**Luego follows Clean Architecture principles. See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.**

```
Luego/
├── Domain/                                  # Pure business logic (NO dependencies)
│   ├── Domain.swift                         # Namespace enum
│   ├── Entities/                            # Domain models (pure Swift)
│   │   ├── DomainArticle.swift
│   │   ├── DomainArticleMetadata.swift
│   │   └── DomainArticleContent.swift
│   ├── UseCases/                            # Business logic operations
│   │   ├── AddArticleUseCase.swift
│   │   ├── DeleteArticleUseCase.swift
│   │   ├── FetchArticleContentUseCase.swift
│   │   ├── GetArticlesUseCase.swift
│   │   ├── UpdateArticleReadPositionUseCase.swift
│   │   └── SyncSharedArticlesUseCase.swift
│   └── RepositoryProtocols/                 # Data access contracts
│       ├── ArticleRepositoryProtocol.swift
│       ├── MetadataRepositoryProtocol.swift
│       └── SharedStorageRepositoryProtocol.swift
│
├── Data/                                    # Data access layer
│   ├── Repositories/                        # Protocol implementations
│   │   ├── ArticleRepository.swift
│   │   ├── MetadataRepository.swift
│   │   └── SharedStorageRepository.swift
│   ├── DataSources/                         # Framework wrappers
│   │   ├── Local/
│   │   │   └── UserDefaultsDataSource.swift
│   │   └── Remote/
│   │       └── HTMLParserDataSource.swift
│   └── DTOs/                                # Data mappers
│       ├── ArticleMapper.swift
│       └── MetadataMapper.swift
│
├── Presentation/                            # UI layer
│   ├── ArticleList/
│   │   ├── ArticleListViewModel.swift       # Observable state with use cases
│   │   ├── ArticleRowViewNew.swift          # List row component
│   │   └── AddArticleViewNew.swift          # URL input sheet
│   └── Reader/
│       ├── ReaderViewModel.swift            # Reader state management
│       └── ReaderViewNew.swift              # Reader view with markdown
│
├── Core/                                    # Infrastructure
│   ├── DI/
│   │   └── DIContainer.swift                # Dependency injection container
│   └── Configuration/
│       └── AppConfiguration.swift           # App-wide constants
│
├── Models/                                  # SwiftData persistence models
│   ├── Article.swift                        # @Model for SwiftData
│   ├── ArticleMetadata.swift
│   └── ArticleContent.swift
│
├── Services/                                # Legacy services (wrapped by data layer)
│   ├── ArticleMetadataService.swift
│   └── SharedStorage.swift
│
├── LuegoApp.swift                           # App entry point with DI setup
├── ContentView.swift                        # Main list view
├── Assets.xcassets/                         # App icons and assets
├── FEATURES.md                              # Feature tracking
├── ARCHITECTURE.md                          # Architecture documentation
└── CLAUDE.md                                # This file
```

### Key Files
- **LuegoApp.swift**: App entry point with DIContainer initialization and environment injection
- **ContentView.swift**: Main article list view using ArticleListViewModel from DI
- **DIContainer.swift**: Manages all dependencies (repositories, use cases, ViewModels)
- **Domain/Entities/**: Pure Swift domain models (no framework dependencies)
- **Domain/UseCases/**: Business logic operations (testable, framework-independent)
- **Data/Repositories/**: Implement repository protocols, coordinate data sources
- **Presentation/**: ViewModels and Views using domain entities

## Architecture & Patterns

### Clean Architecture
The app follows **Clean Architecture** with clear separation of concerns:

**Dependency Flow** (always inward):
```
Presentation → Domain ← Data
```

**Layers:**
1. **Domain** (Pure Swift): Entities, Use Cases, Repository Protocols
   - NO framework dependencies
   - Contains all business logic
   - Defines WHAT the app does

2. **Data** (Implementation): Repositories, Data Sources, DTOs
   - Implements domain protocols
   - Wraps frameworks (SwiftData, URLSession)
   - Handles HOW data is stored/fetched

3. **Presentation** (UI): Views, ViewModels
   - Depends only on domain
   - Uses dependency injection
   - Manages UI state

**Key Benefits:**
- **Testability**: Domain layer fully testable without mocking
- **Maintainability**: Clear boundaries, single responsibility
- **Flexibility**: Swap frameworks without touching business logic
- **Scalability**: Easy to add features, parallel development

### Modern Swift Features
- **@Observable**: Modern observation framework (replaces ObservableObject)
- **async/await**: All network calls use Swift concurrency
- **@MainActor**: UI updates isolated to main thread
- **#Preview**: Modern preview macro syntax
- **Structured Concurrency**: Task-based async operations

### State Management
- **ViewModels** use @Observable for reactive state
- **Dependency Injection**: ViewModels receive dependencies via constructor
- **Domain Entities**: Views work with domain models, not persistence models
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

**Current Dependencies:**
- **SwiftSoup 2.11.1** - HTML parsing for metadata extraction (Open Graph tags, title, description)
  - Repository: https://github.com/scinfu/SwiftSoup.git
  - Used in ArticleMetadataService for parsing fetched HTML content

**Package Resolution:**
- `Package.resolved` location: `Luego.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Xcode handles dependency resolution automatically
- No manual package commands needed

## Feature Tracking

**For detailed feature status, implementation progress, and roadmap, see [FEATURES.md](FEATURES.md)**

The FEATURES.md file tracks:
- MVP feature checklist with implementation status
- Technical implementation details
- Known limitations and current constraints
- Next priority features
- Build status and project structure
- User journey flows

## Development Patterns

### Adding New Features (Clean Architecture Approach)
1. **Define Domain Entity** in `/Domain/Entities/` if needed (pure Swift struct)
2. **Define Repository Protocol** in `/Domain/RepositoryProtocols/` for data access
3. **Create Use Case** in `/Domain/UseCases/` for business logic
4. **Implement Repository** in `/Data/Repositories/` (implement protocol)
5. **Create Data Source** in `/Data/DataSources/` if needed (wrap framework)
6. **Create/Update ViewModel** in `/Presentation/` with injected use cases
7. **Create View** in `/Presentation/` using domain entities
8. **Wire up in DIContainer** - add use case/ViewModel factory methods
9. Update FEATURES.md to track implementation progress

**Example**: Adding "Favorite Articles" feature
```
1. Domain/Entities/: Add `isFavorite: Bool` to Domain.Article
2. Domain/RepositoryProtocols/: Add `toggleFavorite(id:)` to ArticleRepositoryProtocol
3. Domain/UseCases/: Create ToggleFavoriteUseCase.swift
4. Data/Repositories/: Implement `toggleFavorite` in ArticleRepository
5. Core/DI/: Add toggleFavoriteUseCase to DIContainer
6. Presentation/: Use case in ArticleListViewModel
7. Presentation/: Add favorite button to ArticleRowViewNew
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
3. Run tests with ⌘U or `xcodebuild test -project Luego.xcodeproj -scheme Luego -destination 'platform=iOS Simulator,name=<SIMULATOR_NAME>'`
   (Check available simulators first using `xcrun simctl list devices available | grep "iPhone"`)

**Recommended Test Coverage:**
- ArticleMetadataService: URL validation, HTML parsing, error handling
- ArticleListViewModel: Add/delete operations, state management
- Article model: Codable conformance, domain computation
