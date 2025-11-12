# Luego Architecture

Luego follows a **pragmatic architecture** organized by feature with shared infrastructure for maintainability and simplicity.

## Architecture Overview

```
┌────────────────────────────────────────────────────────┐
│                  Feature Modules                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Article     │  │    Reader    │  │   Sharing    │  │
│  │ Management   │  │              │  │              │  │
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
│   ├── ArticleManagement/             # Save, list, and delete articles
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

**Current Features**:
1. **ArticleManagement**: Add, list, and delete articles
2. **Reader**: View article content, track reading position
3. **Sharing**: Share extension integration, sync shared URLs

**Benefits**:
- All feature code in one place
- Easy to understand feature scope
- Clear boundaries between features
- Facilitates parallel development

### 🟩 Core (Horizontal Slice)

**Purpose**: Contains shared infrastructure used by multiple features.

**Rules**:
- NO feature-specific logic
- Common models, infrastructure, and data sources
- Shared persistence and data transfer objects

**Components**:
- **Models**: SwiftData @Model classes and DTO structs (`Article`, `ArticleMetadata`, `ArticleContent`)
- **DataSources**: Framework wrappers (HTML parsing, etc.)
- **DI**: Dependency injection container
- **Configuration**: App-wide configuration

**Example - Use Case**:
```swift
protocol AddArticleUseCaseProtocol: Sendable {
    func execute(url: URL) async throws -> Article
}

final class AddArticleUseCase: AddArticleUseCaseProtocol {
    private let articleRepository: ArticleRepositoryProtocol
    private let metadataRepository: MetadataRepositoryProtocol

    init(
        articleRepository: ArticleRepositoryProtocol,
        metadataRepository: MetadataRepositoryProtocol
    ) {
        self.articleRepository = articleRepository
        self.metadataRepository = metadataRepository
    }

    func execute(url: URL) async throws -> Article {
        let validatedURL = try await metadataRepository.validateURL(url)
        let metadata = try await metadataRepository.fetchMetadata(for: validatedURL)

        let article = Article(
            id: UUID(),
            url: validatedURL,
            title: metadata.title,
            // ...
        )

        return try await articleRepository.save(article)
    }
}
```

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

**Example - Repository**:
```swift
@MainActor
final class ArticleRepository: ArticleRepositoryProtocol {
    private let modelContext: ModelContext

    func getAll() async throws -> [Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func save(_ article: Article) async throws -> Article {
        modelContext.insert(article)
        try modelContext.save()
        return article
    }
}
```

**Example - ViewModel (in Features/*/Views/)**:
```swift
@Observable
@MainActor
final class ArticleListViewModel {
    var articles: [Article] = []
    var isLoading = false
    var errorMessage: String?

    private let getArticlesUseCase: GetArticlesUseCase
    private let addArticleUseCase: AddArticleUseCase

    init(
        getArticlesUseCase: GetArticlesUseCase,
        addArticleUseCase: AddArticleUseCase
    ) {
        self.getArticlesUseCase = getArticlesUseCase
        self.addArticleUseCase = addArticleUseCase
    }

    func loadArticles() async {
        do {
            articles = try await getArticlesUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

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

Dependencies are managed through the `DIContainer`:

```swift
@MainActor
final class DIContainer {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Lazy initialization ensures single instances
    private lazy var articleRepository: ArticleRepositoryProtocol = {
        ArticleRepository(modelContext: modelContext)
    }()

    private lazy var addArticleUseCase: AddArticleUseCaseProtocol = {
        AddArticleUseCase(
            articleRepository: articleRepository,
            metadataRepository: metadataRepository
        )
    }()

    // Factory methods for ViewModels
    func makeArticleListViewModel() -> ArticleListViewModel {
        ArticleListViewModel(
            getArticlesUseCase: getArticlesUseCase,
            addArticleUseCase: addArticleUseCase,
            // ...
        )
    }
}
```

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
