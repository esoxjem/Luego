# Luego Architecture

Luego follows a **pragmatic architecture** organized by feature with shared infrastructure for maintainability and scalability.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  Feature Modules                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Article     │  │    Reader    │  │   Sharing    │  │
│  │ Management   │  │              │  │              │  │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤  │
│  │ • UseCases   │  │ • UseCases   │  │ • UseCases   │  │
│  │ • Views      │  │ • Views      │  │ • Views      │  │
│  │ • ViewModels │  │ • ViewModels │  │ • Repos*     │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                 │           │
└─────────┼─────────────────┼─────────────────┼───────────┘
          │                 │                 │
          └─────────────────┼─────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│              Shared Infrastructure                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Models: SwiftData @Model classes & DTOs         │   │
│  │ Article, ArticleMetadata, ArticleContent        │   │
│  ├─────────────────────────────────────────────────┤   │
│  │ DataSources: Framework wrappers                 │   │
│  │ HTMLParser, ArticleMetadataService              │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
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
│   ├── DataSources/                   # Framework wrappers (if needed)
│   │   ├── HTMLParserDataSource.swift
│   │   └── ArticleMetadataService.swift
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
final class DefaultAddArticleUseCase: AddArticleUseCase {
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

    private lazy var addArticleUseCase: AddArticleUseCase = {
        DefaultAddArticleUseCase(
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

## Benefits of This Architecture

### 🔧 Maintainability
- **Clear Organization**: Feature-based structure with shared models
- **Easy to Navigate**: Predictable structure
- **Reduced Boilerplate**: No domain mapping layers

### 🧪 Testability
- **Use Cases**: Test with mock repositories
- **ViewModels**: Test with mock use cases
- **Repositories**: Integration test with in-memory SwiftData

### 📈 Scalability
- **Add Features**: Create new use cases without modifying existing code
- **Parallel Development**: Teams can work on different features independently
- **Clear Contracts**: Repository protocols define clear interfaces

### ⚡ Simplicity
- **Direct Model Usage**: SwiftData models used throughout the app
- **Less Code**: No mapping between domain and persistence layers
- **Pragmatic**: Right level of abstraction for the app's complexity

## Design Principles

### SOLID Principles

**Single Responsibility**:
- Each class has one reason to change
- Use cases do one thing well

**Open/Closed**:
- Open for extension (add new use cases)
- Closed for modification (don't change existing)

**Liskov Substitution**:
- Repositories can be swapped with any implementation
- Views work with any ViewModel conforming to protocol

**Interface Segregation**:
- Small, focused protocols
- Repository protocols define only what's needed

**Dependency Inversion**:
- High-level domain doesn't depend on low-level data
- Both depend on abstractions (protocols)

### Clean Code Practices

- **No Comments**: Self-documenting code with clear function names
- **Minimal Side Effects**: Logic is as pure as practical
- **Explicit Dependencies**: Constructor injection, no singletons in new code

## Testing Strategy

### Unit Tests (Domain Layer)
```swift
class AddArticleUseCaseTests: XCTestCase {
    func testAddArticle_success() async throws {
        let mockRepo = MockArticleRepository()
        let useCase = DefaultAddArticleUseCase(
            articleRepository: mockRepo,
            metadataRepository: MockMetadataRepository()
        )

        let article = try await useCase.execute(url: testURL)

        XCTAssertEqual(mockRepo.savedArticles.count, 1)
    }
}
```

### Integration Tests (Data Layer)
```swift
class ArticleRepositoryTests: XCTestCase {
    func testSaveAndRetrieve() async throws {
        let container = try ModelContainer(
            for: Article.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = ArticleRepository(modelContext: container.mainContext)

        let article = Domain.Article(/* ... */)
        let saved = try await repo.save(article)
        let retrieved = try await repo.getAll()

        XCTAssertEqual(retrieved.first?.id, saved.id)
    }
}
```

### UI Tests (Presentation Layer)
```swift
class ArticleListViewModelTests: XCTestCase {
    @MainActor
    func testLoadArticles() async {
        let mockUseCase = MockGetArticlesUseCase()
        let viewModel = ArticleListViewModel(
            getArticlesUseCase: mockUseCase,
            // ...
        )

        await viewModel.loadArticles()

        XCTAssertEqual(viewModel.articles.count, mockUseCase.articles.count)
    }
}
```

## Migration History

- **Phase 1**: Foundation & Infrastructure (directories, DI container)
- **Phase 2**: Domain Layer (entities, use cases, protocols)
- **Phase 3**: Data Layer (repositories, data sources, mappers)
- **Phase 4**: Presentation Layer (ViewModels, views with DI)
- **Phase 5**: Cleanup (removed legacy code, documentation)
- **Phase 6**: Feature-Based Restructuring (organized by feature with shared infrastructure)
  - Reorganized from layer-based (Domain/Data/Presentation) to feature-based (Features/Core)
  - Created Features/ with ArticleManagement, Reader, and Sharing modules
  - Moved shared infrastructure to Core/ (Entities, Repositories, DataSources, Models)
  - Moved app entry to App/ directory
  - Maintained Clean Architecture principles within new structure
  - All tests passing, build successful
- **Phase 7**: Repository Consolidation (co-located protocols with implementations)
  - Merged repository protocols into implementation files
  - Removed separate RepositoryProtocols/ directory
  - Moved repositories from Core/ to Features/*/Repositories/
  - ArticleRepository and MetadataRepository → Features/ArticleManagement/Repositories/
  - SharedStorageRepository remains in Features/Sharing/Repositories/
  - Improved code locality and reduced file count
  - Build successful
- **Phase 8**: Mapper Consolidation (co-located mappings with models)
  - Moved domain mapping extensions into model files
  - Article, ArticleMetadata, ArticleContent now contain their own toDomain/fromDomain methods
  - Removed separate DTOs/ directory with ArticleMapper and MetadataMapper files
  - Improved code locality - models now fully self-contained
  - Build successful
- **Phase 9**: Architecture Simplification (removed domain layer)
  - Eliminated separate Domain.Article, Domain.ArticleMetadata, Domain.ArticleContent entities
  - Use SwiftData models directly throughout application
  - Removed all toDomain/fromDomain mapping methods
  - Deleted Core/Entities/ directory and Domain.swift namespace
  - Updated all use cases, repositories, and ViewModels to work with models directly
  - Simplified architecture: pragmatic approach for app's complexity
  - Reduced boilerplate while maintaining testability
  - Build successful
- **Phase 10**: Directory Consolidation (merged Shared into Core)
  - Consolidated Shared/ into Core/ to reduce top-level directories
  - Moved Shared/Models/ → Core/Models/
  - Updated all documentation to reflect Core as the single shared infrastructure directory
  - Clearer semantics: Core contains all shared code (infrastructure + models)
  - Build successful

## Future Enhancements

- [ ] Add unit tests for all use cases
- [ ] Add integration tests for repositories
- [ ] Add UI tests for critical user flows
- [ ] Consider adding coordinator pattern for complex navigation
- [ ] Implement offline-first architecture with sync
- [ ] Add analytics layer following same principles
