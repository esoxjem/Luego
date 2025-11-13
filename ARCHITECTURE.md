# Luego Architecture

Luego follows a **pragmatic architecture** organized by feature with shared infrastructure for maintainability and simplicity.

## Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│                  Feature Modules                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Reading     │  │    Reader    │  │   Sharing    │  │
│  │    List      │  │              │  │              │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ • UseCases   │  │ • UseCases   │  │ • UseCases   │  │
│  │ • Views      │  │ • Views      │  │ • Views      │  │
│  │ • ViewModels │  │ • ViewModels │  │ • Repos*     │  │
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
│  │ DI Container, App Configuration                 │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

**Organization Strategy:**
- **Vertical Slices** (Features/): Group related use cases and views by feature
- **Horizontal Slice** (Core/): Common models, infrastructure, and data sources
- **Direct Model Usage**: Use SwiftData models throughout for simplicity

## Project Structure

```
Luego/
├── Features/                          # Feature modules (vertical slices)
│   ├── ReadingList/                   # Save, list, and delete articles
│   │   ├── UseCases/
│   │   │   ├── AddArticleUseCase.swift
│   │   │   ├── GetArticlesUseCase.swift
│   │   │   └── DeleteArticleUseCase.swift
│   │   ├── Repositories/
│   │   │   ├── ArticleRepository.swift    # Protocol + implementation
│   │   │   └── MetadataRepository.swift   # Protocol + implementation
│   │   └── Views/
│   │       ├── ArticleListViewModel.swift
│   │       ├── ArticleRowView.swift
│   │       └── AddArticleView.swift
│   │
│   ├── Reader/                        # Read articles with position tracking
│   │   ├── UseCases/
│   │   │   ├── FetchArticleContentUseCase.swift
│   │   │   └── UpdateArticleReadPositionUseCase.swift
│   │   └── Views/
│   │       ├── ReaderViewModel.swift
│   │       └── ReaderView.swift
│   │
│   └── Sharing/                       # Share extension integration
│       ├── UseCases/
│       │   └── SyncSharedArticlesUseCase.swift
│       ├── Repositories/
│       │   └── SharedStorageRepository.swift  # Protocol + implementation
│       └── DataSources/
│           ├── UserDefaultsDataSource.swift
│           └── SharedStorage.swift
│
├── Core/                              # Shared infrastructure (horizontal slice)
│   ├── Models/                        # SwiftData models & DTOs
│   │   ├── Article.swift              # @Model class (persistence)
│   │   ├── ArticleMetadata.swift      # DTO struct
│   │   └── ArticleContent.swift       # DTO struct
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
- Contains use cases specific to that feature
- Contains views and view models for that feature
- May contain feature-specific repositories (e.g., Sharing)


### 🟩 Core (Horizontal Slice)

**Purpose**: Contains shared infrastructure used by multiple features.

**Rules**:
- NO feature-specific logic
- Common models, infrastructure, and data sources
- Shared persistence and data transfer objects

**Components**:
- **Models**: SwiftData @Model classes
- **DI**: Dependency injection container
- **Configuration**: App-wide configuration

### 🟦 Architecture Principles

The architecture maintains separation of concerns with a pragmatic approach:

**Business Logic (Use Cases)**:
- Located in Features/*/UseCases/
- Minimal framework dependencies
- Depend on repository protocols from Features/*/Repositories/
- Coordinate operations between repositories

**Data Access (Repositories)**:
- Located in Features/*/Repositories/
- Each repository contains both protocol and implementation
- Work directly with SwiftData models
- Handle persistence and external data

**Presentation (Views & ViewModels)**:
- Located in Features/*/Views/
- Depend on use cases and models
- Use dependency injection for testability

## Data Flow

### Reading Articles
```
View → ViewModel → Use Case → Repository → Data Source → Database
                                                            ↓
View ← ViewModel ← Use Case ← Repository ← Data Source ← [Article]
```

### Adding an Article
```
User Input (URL)
    ↓
AddArticleView
    ↓
ArticleListViewModel.addArticle(url)
    ↓
AddArticleUseCase.execute(url)
    ├→ MetadataRepository.validateURL()
    ├→ MetadataRepository.fetchMetadata()
    └→ ArticleRepository.save()
           ↓
       SwiftData
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
