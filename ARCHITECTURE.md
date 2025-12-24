# Luego Architecture

Luego follows a **service-based architecture** organized by feature with shared infrastructure for maintainability and simplicity.

## Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│                  Feature Modules                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Reading     │  │    Reader    │  │  Discovery   │  │
│  │    List      │  │              │  │              │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ • Services   │  │ • Services   │  │ • Services   │  │
│  │ • Views      │  │ • Views      │  │ • DataSources│  │
│  │ • ViewModels │  │ • ViewModels │  │ • Views      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                 │          │
└─────────┼─────────────────┼─────────────────┼──────────┘
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ↓
┌────────────────────────────────────────────────────────┐
│              Core (Shared Infrastructure)              │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Models: SwiftData @Model classes                │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ DataSources: Shared data access                 │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ DI Container, App Configuration                 │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

**Organization Strategy:**
- **Vertical Slices** (Features/): Group services and views by feature
- **Horizontal Slice** (Core/): Common models, infrastructure, and shared data sources
- **Direct Model Usage**: Use SwiftData models throughout for simplicity

## Project Structure

```
Luego/
├── Features/                          # Feature modules (vertical slices)
│   ├── ReadingList/                   # Save, list, and delete articles
│   │   ├── Services/
│   │   │   └── ArticleService.swift   # CRUD operations for articles
│   │   └── Views/
│   │       ├── ArticleListViewModel.swift
│   │       ├── ArticleRowView.swift
│   │       └── AddArticleView.swift
│   │
│   ├── Reader/                        # Read articles with position tracking
│   │   ├── Services/
│   │   │   └── ReaderService.swift    # Content fetching, position updates
│   │   └── Views/
│   │       ├── ReaderViewModel.swift
│   │       └── ReaderView.swift
│   │
│   ├── Discovery/                     # Random article exploration
│   │   ├── Services/
│   │   │   └── DiscoveryService.swift # Random article fetching
│   │   ├── DataSources/
│   │   │   ├── KagiSmallWebDataSource.swift
│   │   │   └── BlogrollDataSource.swift
│   │   └── Views/
│   │       ├── DiscoveryViewModel.swift
│   │       └── DiscoveryView.swift
│   │
│   ├── Sharing/                       # Share extension integration
│   │   ├── Services/
│   │   │   └── SharingService.swift   # Sync shared articles
│   │   └── DataSources/
│   │       ├── UserDefaultsDataSource.swift
│   │       └── SharedStorage.swift
│   │
│   └── Settings/                      # App settings
│       └── Views/
│           ├── SettingsViewModel.swift
│           └── SettingsView.swift
│
├── Core/                              # Shared infrastructure (horizontal slice)
│   ├── Models/                        # SwiftData models & DTOs
│   │   ├── Article.swift              # @Model class (persistence)
│   │   ├── ArticleMetadata.swift      # DTO struct + errors
│   │   ├── ArticleContent.swift       # DTO struct
│   │   ├── EphemeralArticle.swift     # Non-persisted article
│   │   └── DiscoverySource.swift      # Discovery source enum
│   ├── DataSources/                   # Shared data access
│   │   ├── MetadataDataSource.swift   # URL validation, content fetching
│   │   └── SeenItemTracker.swift      # Track seen items
│   ├── DI/
│   │   └── DIContainer.swift
│   └── Configuration/
│       └── AppConfiguration.swift
│
└── App/                               # Application entry point
    ├── LuegoApp.swift
    └── ContentView.swift
```

## Architecture Responsibilities

### 🟪 Features (Vertical Slices)

**Purpose**: Group related functionality by feature for better cohesion and locality.

**Rules**:
- Each feature is a self-contained module
- Contains services specific to that feature
- Contains views and view models for that feature
- May contain feature-specific data sources (e.g., Discovery, Sharing)


### 🟩 Core (Horizontal Slice)

**Purpose**: Contains shared infrastructure used by multiple features.

**Rules**:
- NO feature-specific logic
- Common models, infrastructure, and shared data sources
- Shared persistence and data transfer objects

**Components**:
- **Models**: SwiftData @Model classes and DTOs
- **DataSources**: Shared data access (MetadataDataSource)
- **DI**: Dependency injection container
- **Configuration**: App-wide configuration

### 🟦 Architecture Principles

The architecture maintains separation of concerns with a pragmatic approach:

**Business Logic & Data Access (Services)**:
- Located in Features/*/Services/
- Combine business logic with data access for simplicity
- Work directly with SwiftData models
- Handle persistence and external data
- All service classes marked with `@MainActor` (required for SwiftData's ModelContext)

**Data Sources**:
- Located in Core/DataSources/ (shared) or Features/*/DataSources/ (feature-specific)
- Handle external data fetching (network, APIs)
- Protocol-based for testability

**Presentation (Views & ViewModels)**:
- Located in Features/*/Views/
- Depend on services and models
- Use dependency injection for testability

## Data Flow

### Reading Articles
```
View → ViewModel → Service → SwiftData
                                  ↓
View ← ViewModel ← Service ← [Article]
```

### Adding an Article
```
User Input (URL)
    ↓
AddArticleView
    ↓
ArticleListViewModel.addArticle(url)
    ↓
ArticleService.addArticle(url)
    ├→ MetadataDataSource.validateURL()
    ├→ MetadataDataSource.fetchMetadata()
    └→ ModelContext.insert() + save()
           ↓
       SwiftData
```

### Discovery Flow
```
DiscoveryView
    ↓
DiscoveryViewModel.fetchRandomArticle()
    ↓
DiscoveryService.fetchRandomArticle()
    ├→ KagiSmallWebDataSource.randomArticleEntry()
    └→ MetadataDataSource.fetchContent()
           ↓
    EphemeralArticle (non-persisted)
           ↓
    [User saves] → ArticleService.saveEphemeralArticle()
```

## Dependency Injection

Dependencies are managed through the `DIContainer`

**Usage in SwiftUI**:
```swift
@main
struct LuegoApp: App {
    var sharedModelContainer: ModelContainer = { /* ... */ }()

    @MainActor
    private var diContainer: DIContainer {
        DIContainer(modelContext: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.diContainer, diContainer)
        }
    }
}
```

## Service Protocols

### ArticleService
```swift
protocol ArticleServiceProtocol: Sendable {
    func getAllArticles() async throws -> [Article]
    func addArticle(url: URL) async throws -> Article
    func deleteArticle(id: UUID) async throws
    func updateArticle(_ article: Article) async throws
    func toggleFavorite(id: UUID) async throws
    func toggleArchive(id: UUID) async throws
    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article
}
```

### ReaderService
```swift
protocol ReaderServiceProtocol: Sendable {
    func fetchContent(for article: Article, forceRefresh: Bool) async throws -> Article
    func updateReadPosition(articleId: UUID, position: Double) async throws
}
```

### DiscoveryService
```swift
protocol DiscoveryServiceProtocol: Sendable {
    func fetchRandomArticle(from source: DiscoverySource, onArticleEntryFetched: @escaping @MainActor (URL) -> Void) async throws -> EphemeralArticle
    func prepareForFetch(source: DiscoverySource) -> DiscoverySource
    func clearCache(for source: DiscoverySource)
    func clearAllCaches()
}
```

### SharingService
```swift
protocol SharingServiceProtocol: Sendable {
    func syncSharedArticles() async throws -> [Article]
}
```

## ViewModel Dependencies

| ViewModel | Dependencies |
|-----------|--------------|
| ArticleListViewModel | ArticleService, SharingService |
| ReaderViewModel | ReaderService |
| DiscoveryViewModel | DiscoveryService, ArticleService, PreferencesDataSource |
| SettingsViewModel | DiscoveryService, PreferencesDataSource |
