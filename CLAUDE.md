# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Readit** is a minimal read-it-later iOS application that allows users to save articles from URLs, fetch metadata automatically, and manage a reading list. Built with SwiftUI and Swift 5.0, targeting iOS 26.0+.

- **Bundle ID**: com.esoxjem.Readit
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
open Readit.xcodeproj
```

## Development Commands

### Building
- **Build**: ⌘B in Xcode, or `xcodebuild -project Readit.xcodeproj -scheme Readit -configuration Debug build`
- **Run**: ⌘R in Xcode to build and run on simulator or connected device
- **Clean**: ⌘⇧K in Xcode, or `xcodebuild clean -project Readit.xcodeproj -scheme Readit`

### Running on Specific Simulators
**IMPORTANT: Always check available simulators before building**

```bash
# List available iPhone simulators
xcrun simctl list devices available | grep "iPhone"

# Build and run on specific simulator (use a simulator from the list above)
xcodebuild -project Readit.xcodeproj -scheme Readit -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Note:** Simulator names vary by Xcode version. Always check available simulators first and use an exact name from the list.

## Project Structure

```
Readit/
├── Readit/
│   ├── ReaditApp.swift                      # App entry point (@main)
│   ├── ContentView.swift                    # Main article list view with navigation
│   ├── Models/
│   │   ├── Article.swift                    # Core data model (Identifiable, Codable)
│   │   ├── ArticleMetadata.swift            # Metadata struct (title, thumbnail, description)
│   │   └── ArticleContent.swift             # Full content struct (includes parsed body)
│   ├── Services/
│   │   └── ArticleMetadataService.swift     # URL fetching, HTML parsing, content extraction
│   ├── ViewModels/
│   │   └── ArticleListViewModel.swift       # List state & business logic (@Observable)
│   ├── Views/
│   │   ├── AddArticleView.swift             # URL input modal sheet
│   │   ├── ArticleRowView.swift             # List row component
│   │   └── ReaderView.swift                 # Reader mode with WebView fallback
│   ├── Assets.xcassets/                     # App icons and assets
│   ├── FEATURES.md                          # Feature tracking document
│   └── CLAUDE.md                            # This file
└── Readit.xcodeproj/
```

### Key Files
- **ReaditApp.swift**: SwiftUI app entry point with `@main` attribute
- **ContentView.swift**: Main list view with NavigationStack, NavigationLink to reader, empty states, and toolbar
- **Article.swift**: Core data model with id, url, title, content, savedDate, thumbnailURL, and computed `domain` property
- **ArticleMetadata.swift**: Metadata struct for basic article info (title, thumbnail, description)
- **ArticleContent.swift**: Full content struct including parsed article body text
- **ArticleMetadataService.swift**: Singleton service for fetching HTML, parsing metadata (Open Graph tags), and extracting article content with readability algorithm
- **ArticleListViewModel.swift**: Observable state management with addArticle, deleteArticle, fetchArticleContent, error handling
- **AddArticleView.swift**: Form view for URL input with validation and error display
- **ArticleRowView.swift**: Reusable row component with AsyncImage thumbnail support
- **ReaderView.swift**: Clean reader mode with parsed content display, WKWebView fallback, loading states, and share functionality

## Architecture & Patterns

### MVVM Architecture
The app follows Model-View-ViewModel pattern with a service layer:

**Data Flow:**
1. **Views** (SwiftUI) → User interactions trigger events
2. **ViewModels** (@Observable) → Handle business logic and state
3. **Services** (Singleton) → Perform network requests, data operations
4. **Models** (Codable) → Data structures passed between layers

**Key Patterns:**
- **Models** (`/Models/`): Pure data structures - Article.swift, ArticleMetadata.swift, ArticleContent.swift (one struct per file)
- **Views** (`/Views/`, ContentView.swift): SwiftUI views with minimal logic
- **ViewModels** (`/ViewModels/`): State management with @Observable macro
- **Services** (`/Services/`): Business logic, networking, HTML parsing, content extraction

### Modern Swift Features
- **@Observable**: Modern observation framework (replaces ObservableObject)
- **async/await**: All network calls use Swift concurrency
- **@MainActor**: UI updates isolated to main thread
- **#Preview**: Modern preview macro syntax
- **Structured Concurrency**: Task-based async operations

### State Management
- **ArticleListViewModel** uses @Observable for reactive state
- Views use @State for local state and @Bindable for passing observable objects
- No Combine framework (using modern Observation instead)

### Service Layer Pattern
- **ArticleMetadataService.shared**: Singleton for article metadata fetching
- Separation of concerns: Services handle I/O, ViewModels handle state
- Error handling with custom error types (ArticleMetadataError)

## Dependencies

### Swift Package Manager
The project uses SwiftSPM for dependency management. Dependencies are declared in the Xcode project and resolved automatically on first build.

**Current Dependencies:**
- **SwiftSoup 2.11.1** - HTML parsing for metadata extraction (Open Graph tags, title, description)
  - Repository: https://github.com/scinfu/SwiftSoup.git
  - Used in ArticleMetadataService for parsing fetched HTML content

**Package Resolution:**
- `Package.resolved` location: `Readit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
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

### Adding New Features
1. Create model in `/Models/` if needed (Codable, Identifiable) - **one struct per file**
2. Add business logic to service in `/Services/` or create new service
3. Create/update ViewModel in `/ViewModels/` with @Observable
4. Create views in `/Views/` with SwiftUI
5. Wire up in ContentView or navigation structure
6. Update FEATURES.md to track implementation progress

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
3. Run tests with ⌘U or `xcodebuild test -project Readit.xcodeproj -scheme Readit -destination 'platform=iOS Simulator,name=<SIMULATOR_NAME>'`
   (Check available simulators first using `xcrun simctl list devices available | grep "iPhone"`)

**Recommended Test Coverage:**
- ArticleMetadataService: URL validation, HTML parsing, error handling
- ArticleListViewModel: Add/delete operations, state management
- Article model: Codable conformance, domain computation
