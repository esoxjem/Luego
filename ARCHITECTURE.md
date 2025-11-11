# Luego Architecture

Luego follows **Clean Architecture** principles to ensure maintainability, testability, and scalability.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (SwiftUI Views, ViewModels, UI State)                  │
│  Dependencies: Domain interfaces only                    │
└──────────────────┬──────────────────────────────────────┘
                   │ (depends on)
┌──────────────────▼──────────────────────────────────────┐
│                     Domain Layer                         │
│  (Entities, Use Cases, Repository Protocols)            │
│  Dependencies: NONE (pure Swift)                        │
└──────────────────▲──────────────────────────────────────┘
                   │ (implements)
┌──────────────────┴──────────────────────────────────────┐
│                      Data Layer                          │
│  (Repository Implementations, Data Sources, DTOs)       │
│  Dependencies: Domain + Frameworks (SwiftData, Network) │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
Luego/
├── Domain/                     # Pure business logic (NO dependencies)
│   ├── Domain.swift            # Namespace enum
│   ├── Entities/               # Domain models
│   │   ├── DomainArticle.swift
│   │   ├── DomainArticleMetadata.swift
│   │   └── DomainArticleContent.swift
│   ├── UseCases/               # Business logic operations
│   │   ├── AddArticleUseCase.swift
│   │   ├── DeleteArticleUseCase.swift
│   │   ├── FetchArticleContentUseCase.swift
│   │   ├── GetArticlesUseCase.swift
│   │   ├── UpdateArticleReadPositionUseCase.swift
│   │   └── SyncSharedArticlesUseCase.swift
│   └── RepositoryProtocols/    # Data access contracts
│       ├── ArticleRepositoryProtocol.swift
│       ├── MetadataRepositoryProtocol.swift
│       └── SharedStorageRepositoryProtocol.swift
│
├── Data/                       # Data access implementations
│   ├── Repositories/
│   │   ├── ArticleRepository.swift
│   │   ├── MetadataRepository.swift
│   │   └── SharedStorageRepository.swift
│   ├── DataSources/
│   │   ├── Local/
│   │   │   └── UserDefaultsDataSource.swift
│   │   └── Remote/
│   │       └── HTMLParserDataSource.swift
│   └── DTOs/                   # Data transfer objects & mappers
│       ├── ArticleMapper.swift
│       └── MetadataMapper.swift
│
├── Presentation/               # UI layer
│   ├── ArticleList/
│   │   ├── ArticleListViewModel.swift
│   │   ├── ArticleRowViewNew.swift
│   │   └── AddArticleViewNew.swift
│   └── Reader/
│       ├── ReaderViewModel.swift
│       └── ReaderViewNew.swift
│
├── Core/                       # Infrastructure
│   ├── DI/
│   │   └── DIContainer.swift
│   └── Configuration/
│       └── AppConfiguration.swift
│
├── Models/                     # SwiftData persistence models
│   ├── Article.swift           # @Model for SwiftData
│   ├── ArticleMetadata.swift
│   └── ArticleContent.swift
│
└── Services/                   # Legacy services (wrapped by data layer)
    ├── ArticleMetadataService.swift
    └── SharedStorage.swift
```

## Layer Responsibilities

### 🟦 Domain Layer (Pure Business Logic)

**Purpose**: Contains the core business logic, independent of any frameworks.

**Rules**:
- NO framework dependencies (no SwiftUI, SwiftData, etc.)
- Pure Swift code only
- Defines WHAT the app does, not HOW

**Components**:
- **Entities**: Core business models (`Domain.Article`, `Domain.ArticleMetadata`)
- **Use Cases**: Business operations (e.g., `AddArticleUseCase`, `DeleteArticleUseCase`)
- **Repository Protocols**: Interfaces for data access

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

    func execute(url: URL) async throws -> Domain.Article {
        let validatedURL = try await metadataRepository.validateURL(url)
        let metadata = try await metadataRepository.fetchMetadata(for: validatedURL)

        let article = Domain.Article(
            id: UUID(),
            url: validatedURL,
            title: metadata.title,
            // ...
        )

        return try await articleRepository.save(article)
    }
}
```

### 🟩 Data Layer (Implementation Details)

**Purpose**: Implements data access and persistence, hides framework details.

**Rules**:
- Implements Domain layer protocols
- Can depend on frameworks (SwiftData, URLSession, etc.)
- Converts between framework types and domain types

**Components**:
- **Repositories**: Implement repository protocols, coordinate data sources
- **Data Sources**: Wrap specific frameworks (SwiftData, Network, UserDefaults)
- **DTOs & Mappers**: Convert between persistence models and domain entities

**Example - Repository**:
```swift
@MainActor
final class ArticleRepository: ArticleRepositoryProtocol {
    private let modelContext: ModelContext

    func getAll() async throws -> [Domain.Article] {
        let descriptor = FetchDescriptor<Article>(
            sortBy: [SortDescriptor(\.savedDate, order: .reverse)]
        )
        let articles = try modelContext.fetch(descriptor)
        return articles.map { $0.toDomain() }  // Convert to domain
    }

    func save(_ article: Domain.Article) async throws -> Domain.Article {
        let modelArticle = Article.fromDomain(article)  // Convert from domain
        modelContext.insert(modelArticle)
        try modelContext.save()
        return modelArticle.toDomain()
    }
}
```

### 🟨 Presentation Layer (UI)

**Purpose**: Handles user interface and user interactions.

**Rules**:
- Depends only on Domain layer (use cases, entities)
- Uses dependency injection for testability
- Converts domain data to UI-friendly formats

**Components**:
- **Views**: SwiftUI views (declarative UI)
- **ViewModels**: Manage UI state, call use cases
- **UI State**: Transient state for user interactions

**Example - ViewModel**:
```swift
@Observable
@MainActor
final class ArticleListViewModel {
    var articles: [Domain.Article] = []
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

### 🧪 Testability
- **Domain Layer**: Unit test with pure Swift, no mocking needed
- **Use Cases**: Test with mock repositories
- **ViewModels**: Test with mock use cases
- **Repositories**: Integration test with in-memory database

### 🔧 Maintainability
- **Clear Boundaries**: Each layer has a single responsibility
- **Dependency Direction**: Always inward toward domain
- **Easy to Navigate**: Predictable structure

### 🔄 Flexibility
- **Swap Frameworks**: Replace SwiftData with Core Data or SQLite
- **Change UI**: Migrate from SwiftUI to UIKit without touching domain
- **Mock External Services**: Easy to test without network calls

### 📈 Scalability
- **Add Features**: Create new use cases without modifying existing code
- **Parallel Development**: Teams can work on different layers independently
- **Clear Contracts**: Protocols define clear interfaces

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
- **Pure Functions**: Domain logic is side-effect free where possible
- **Immutability**: Domain entities are value types (structs)
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

## Future Enhancements

- [ ] Add unit tests for all use cases
- [ ] Add integration tests for repositories
- [ ] Add UI tests for critical user flows
- [ ] Consider adding coordinator pattern for complex navigation
- [ ] Implement offline-first architecture with sync
- [ ] Add analytics layer following same principles
