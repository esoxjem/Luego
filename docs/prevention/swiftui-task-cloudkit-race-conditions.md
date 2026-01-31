# Prevention Strategy: SwiftUI Task + CloudKit Race Conditions

## Overview

**Problem Solved**: Race condition in SwiftUI Reader when CloudKit syncs articles during async loading, causing stuck spinners and incomplete loads.

**Root Causes**:
1. `.task` modifier without `id:` restarts unpredictably with @Observable
2. No concurrent operation protection in ViewModels
3. SwiftData actor reentrancy - stale references after suspension points
4. CloudKit sync can modify data during async operations

This document provides best practices and patterns to prevent similar issues in the Luego codebase.

---

## 1. SwiftUI Task Lifecycle Best Practices

### When to Use `.task(id:)` vs `.task`

#### Use `.task` (without `id:`) only when:
- Task should run once when the view appears
- Task should be independent of model changes
- You explicitly want no restarts on any state changes

**Example**:
```swift
var body: some View {
    VStack {
        // ...
    }
    .task {
        // One-time setup: analytics tracking, background sync
        await trackScreenView()
    }
}
```

#### Use `.task(id:)` when:
- Task depends on a specific model property
- Task should restart when that property changes
- Automatic cancellation of previous task is desired
- Different data should trigger fresh operations

**Example**:
```swift
var body: some View {
    VStack {
        // Load article content based on article ID
    }
    .task(id: viewModel.article.id) {
        // Task cancels automatically when article.id changes
        await viewModel.loadContent()
    }
}
```

### Choosing the Right Identity Value

**Critical Rule**: The identity value should be **immutable within the scope of the task**.

```swift
// CORRECT: Use immutable, entity-identifying property
.task(id: viewModel.article.id) {  // UUID never changes for article
    await viewModel.loadContent()
}

// WRONG: Use mutable property that changes during task
.task(id: viewModel.article.title) {  // Could change if article syncs
    await viewModel.loadContent()  // Task restarts unexpectedly
}

// WRONG: Use computed property with side effects
.task(id: viewModel.computedProperty) {  // Changes too frequently
    await viewModel.loadContent()
}
```

### Identity Stability Checklist

Before using `.task(id:)`, verify:
- [ ] Identity value is immutable for the entity's lifetime
- [ ] Identity value uniquely identifies the data to fetch
- [ ] CloudKit sync will not change the identity value
- [ ] View recreations preserve the same identity value
- [ ] No circular dependencies with other observables

---

## 2. @Observable + Task Management Pattern

### Problem with @Observable and Tasks

When using `@Observable` with async operations, CloudKit sync can modify properties during suspension points, causing:
- Unintended task restarts
- Stale data references
- Double-loading scenarios

### Solution: Task Reference Management

Store task references with `@ObservationIgnored` to prevent observation and allow cancellation:

```swift
@Observable
@MainActor
final class ReaderViewModel {
    // Public: Observable properties trigger view updates
    var article: Article
    var articleContent: String?
    var isLoading: Bool = false
    var errorMessage: String?

    // Private: Not observed by SwiftUI, safe for task management
    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?

    private let readerService: ReaderServiceProtocol

    func loadContent() async {
        // Cancel any previous load
        loadingTask?.cancel()

        isLoading = true
        errorMessage = nil

        // Wrap in Task for cancellation control
        let task = Task { [weak self] in
            guard let self else { return }

            do {
                // Check cancellation before long operation
                try Task.checkCancellation()

                let updatedArticle = try await readerService.fetchContent(
                    for: article,
                    forceRefresh: false
                )

                // Check cancellation after suspension
                try Task.checkCancellation()

                // Update observable properties
                article = updatedArticle
                articleContent = updatedArticle.content
            } catch is CancellationError {
                // Gracefully handle cancellation without error UI
                Logger.reader.debug("Load cancelled")
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }

        loadingTask = task
        await task.value
    }
}
```

### Why @ObservationIgnored is Essential

```swift
// WRONG: Task property is observed
@Observable
final class BadViewModel {
    var loadingTask: Task<Void, Never>?  // ⚠️ SwiftUI watches this

    func load() async {
        let task = Task { /* ... */ }
        loadingTask = task  // ⚠️ Triggers view update, causes issues
    }
}

// CORRECT: Task property is hidden from observation
@Observable
final class GoodViewModel {
    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?  // ✓ SwiftUI ignores

    func load() async {
        let task = Task { /* ... */ }
        loadingTask = task  // ✓ No unexpected view updates
    }
}
```

### Cancellation Pattern

Always cancel previous operations before starting new ones:

```swift
func loadContent() async {
    loadingTask?.cancel()  // Stop any in-flight operation

    let task = Task { [weak self] in
        guard let self else { return }

        // First check: Immediately after task creation
        try Task.checkCancellation()

        // Long-running operation
        let result = try await expensiveOperation()

        // Second check: After suspension point
        try Task.checkCancellation()

        // Update state
        self.result = result
    }

    loadingTask = task
    await task.value
}
```

### [weak self] Capture Pattern

Always use `[weak self]` to prevent retain cycles and allow ViewModel deallocation:

```swift
// CORRECT: weak capture allows cleanup
let task = Task { [weak self] in
    guard let self else { return }
    // Safe to use self
    let result = try await self.service.fetch()
    self.property = result
}

// WRONG: strong capture prevents deallocation
let task = Task {
    let result = try await self.service.fetch()  // ⚠️ Retain cycle
    self.property = result
}
```

---

## 3. SwiftData Actor Reentrancy Checklist

### Understanding the Problem

SwiftData uses actors for thread safety. When you have a suspension point (await), the actor may be re-entered by CloudKit sync, causing:
- Stale references to objects
- Lost updates during async operations
- Crashes when accessing modified data

### When to Re-fetch from ModelContext

**Always re-fetch after suspension points if you:**
1. Made assumptions about object state before the suspension
2. Will mutate the object after the suspension
3. Are using a long-lived reference across multiple awaits

```swift
// WRONG: Using stale reference after suspension
func fetchAndUpdate(article: Article) async throws -> Article {
    let content = try await metadataDataSource.fetch(article.url)

    // ⚠️ article reference may be stale now (CloudKit could have synced)
    article.content = content  // ⚠️ Writing to potentially invalid object

    return article
}

// CORRECT: Re-fetch fresh reference after suspension
func fetchAndUpdate(article: Article) async throws -> Article {
    let articleId = article.id  // Capture ID (immutable)

    let content = try await metadataDataSource.fetch(article.url)

    // Re-fetch to get fresh reference with latest CloudKit changes
    let predicate = #Predicate<Article> { $0.id == articleId }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)

    guard let freshArticle = try modelContext.fetch(descriptor).first else {
        throw ReaderServiceError.articleNotFound
    }

    freshArticle.content = content  // ✓ Writing to fresh object
    return freshArticle
}
```

### Re-fetch Checklist

Before suspending and resuming in a service method, ask:

- [ ] Do I need to modify the passed-in object after the suspension point?
- [ ] Is there a chance CloudKit sync modified the object?
- [ ] Should I capture the ID before suspension instead?
- [ ] Can I fetch a fresh reference after the suspension?

### Capture IDs Before Suspension

Prefer capturing immutable identifiers instead of references:

```swift
// GOOD: Capture ID before suspension
func process(article: Article) async throws {
    let articleId = article.id  // Capture before suspension
    let title = article.title   // Capture before suspension

    let newContent = try await fetchContent()

    // Re-fetch with captured ID
    let fresh = try fetch(by: articleId)
    fresh.content = newContent
}

// RISKY: Long-lived reference across suspension
func process(article: Article) async throws {
    let newContent = try await fetchContent()

    article.content = newContent  // article reference may be stale
}
```

---

## 4. CloudKit Sync Defensive Patterns

### Nil Guards for Content Updates

CloudKit can delete records or change properties. Always guard before assuming content exists:

```swift
// WRONG: Assumes metadata always exists
func updateFromSync(article: Article, metadata: ArticleMetadata) {
    article.author = metadata.author  // ⚠️ What if metadata is nil?
    article.wordCount = metadata.wordCount
}

// CORRECT: Defensive nil checks
func updateFromSync(article: Article, metadata: ArticleMetadata) {
    if article.author == nil, let author = metadata.author {
        article.author = author
    }
    if article.wordCount == nil, let wordCount = metadata.wordCount {
        article.wordCount = wordCount
    }
}

// BETTER: Only update if new value provided
func mergeMetadata(into article: Article, from source: ArticleContent) {
    // Merge strategy: preserve local data, add missing metadata
    if article.content == nil {
        article.content = source.content
    }
    if article.author == nil, let author = source.author {
        article.author = author
    }
    if article.wordCount == nil, let wordCount = source.wordCount {
        article.wordCount = wordCount
    }
    if article.thumbnailURL == nil, let url = source.thumbnailURL {
        article.thumbnailURL = url
    }
}
```

### Handling Deleted Entities

If an entity can be deleted during async operations, use optional returns:

```swift
enum ArticleServiceError: Error, LocalizedError {
    case articleNotFound
    case articleDeleted

    var errorDescription: String? {
        switch self {
        case .articleNotFound:
            return "Article not found in database"
        case .articleDeleted:
            return "Article was deleted"
        }
    }
}

// SAFE: Throws error if entity disappears
func fetchContent(for articleId: UUID) async throws -> ArticleContent {
    let predicate = #Predicate<Article> { $0.id == articleId }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)

    guard let article = try modelContext.fetch(descriptor).first else {
        throw ArticleServiceError.articleNotFound
    }

    return try await metadataDataSource.fetch(article.url)
}
```

### Defensive Content Fetching

Protect against partial updates and race conditions:

```swift
// Service method: Safe to CloudKit sync during operation
func updateArticleContent(articleId: UUID, with newContent: String) async throws {
    let predicate = #Predicate<Article> { $0.id == articleId }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)

    // Fetch fresh before suspension
    guard let article = try modelContext.fetch(descriptor).first else {
        throw ArticleServiceError.articleNotFound
    }

    let initialState = article.content

    do {
        // Long operation with potential CloudKit interference
        let enrichedContent = try await enrichContent(newContent)

        // Fetch fresh after suspension
        guard let freshArticle = try modelContext.fetch(descriptor).first else {
            throw ArticleServiceError.articleDeleted
        }

        // Only update if still empty or was recently emptied
        if freshArticle.content == nil || freshArticle.content == initialState {
            freshArticle.content = enrichedContent
            try modelContext.save()
        }
    } catch {
        throw error
    }
}
```

### Error Recovery Patterns

Provide meaningful errors for CloudKit scenarios:

```swift
enum LoadingError: Error, LocalizedError {
    case articleNotFound
    case contentUnavailable
    case networkError(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .articleNotFound:
            return "Article not found. It may have been deleted."
        case .contentUnavailable:
            return "Unable to fetch article content. Try opening in browser."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .cancelled:
            return nil  // Don't show UI for cancellation
        }
    }
}

// ViewModel: Safe error handling
func loadContent() async {
    do {
        let content = try await service.fetch(articleId)
        self.content = content
    } catch is CancellationError {
        // Silently handle cancellation
        Logger.reader.debug("Load cancelled")
    } catch let error as LoadingError {
        // Show user-friendly message
        self.errorMessage = error.errorDescription
    } catch {
        // Unexpected error
        self.errorMessage = "An unexpected error occurred. Please try again."
    }
}
```

---

## 5. Test Cases to Add

### Test: Cancellation Handling

```swift
@Test("loadContent cancels previous load when new load starts")
func loadContentCancelsPreviousLoad() async {
    let article = ArticleFixtures.createArticle(content: nil)
    let viewModel = ReaderViewModel(article: article, readerService: mockService)

    // Start first load
    let firstLoadTask = Task {
        await viewModel.loadContent()
    }

    // Immediately start second load (before first completes)
    let secondLoadTask = Task {
        try await Task.sleep(nanoseconds: 100_000_000)  // Small delay
        await viewModel.loadContent()
    }

    // First task should see cancellation or complete normally
    await firstLoadTask.value
    await secondLoadTask.value

    // Only one successful fetch should occur
    #expect(mockService.fetchContentCallCount == 1)
    #expect(viewModel.isLoading == false)
}
```

### Test: Missing Entity During Async

```swift
@Test("fetchContent throws articleNotFound if deleted during fetch")
func fetchContentThrowsIfDeletedDuringFetch() async throws {
    var article = try createAndPersistArticle(content: nil)
    let articleId = article.id

    // Mock will simulate delay, allowing us to delete
    mockMetadataDataSource.delayFetch = true

    // Delete article from database
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        try? self.deleteArticle(id: articleId)
    }

    // Fetch should fail when article is gone
    await #expect(throws: ReaderServiceError.articleNotFound) {
        try await sut.fetchContent(for: article, forceRefresh: false)
    }
}
```

### Test: State Consistency After CloudKit Sync

```swift
@Test("refreshContent maintains consistency if article syncs during refresh")
func refreshContentHandlesCloudKitSyncDuringRefresh() async throws {
    let article = try createAndPersistArticle(content: "Old content")
    let viewModel = ReaderViewModel(article: article, readerService: sut)

    // Simulate CloudKit sync changing article.title during refresh
    mockService.onBeforeFetch = {
        article.title = "New title from sync"
    }

    await viewModel.refreshContent()

    // Content should be updated, but not cause errors
    #expect(viewModel.articleContent != "Old content")
    #expect(viewModel.isLoading == false)
    #expect(viewModel.errorMessage == nil)
}
```

### Test: Task Cancellation Error Handling

```swift
@Test("loadContent handles CancellationError without error UI")
func loadContentCancellationSilent() async {
    let article = ArticleFixtures.createArticle(content: nil)
    let viewModel = ReaderViewModel(
        article: article,
        readerService: mockService
    )
    mockService.shouldThrowCancellationError = true

    await viewModel.loadContent()

    // Cancellation should not show error message
    #expect(viewModel.errorMessage == nil)
    #expect(viewModel.isLoading == false)
}
```

### Test: Re-fetch Safety

```swift
@Test("service re-fetches fresh article reference after content fetch")
func serviceFetchesFreshReferenceAfterSuspension() async throws {
    let article = try createAndPersistArticle(content: nil)
    let articleId = article.id

    mockMetadataDataSource.contentToReturn = ArticleContent(
        content: "Fresh content",
        /* ... */
    )

    // Modify original reference (simulating CloudKit sync)
    article.title = "Updated title"

    let result = try await sut.fetchContent(for: article, forceRefresh: false)

    // Result should have fresh reference
    let freshFromDB = try fetchArticleById(articleId)
    #expect(freshFromDB?.content == "Fresh content")
    #expect(freshFromDB?.title == "Updated title")
}
```

---

## 6. Code Review Checklist

When reviewing SwiftUI code with async operations:

### View Layer
- [ ] `.task` has `id:` parameter matching the data identifier
- [ ] Identity value is immutable (UUID, not mutable properties)
- [ ] No `.task` without `id:` when observing mutable models
- [ ] Proper loading and error state handling

### ViewModel Layer
- [ ] Task references use `@ObservationIgnored`
- [ ] `Task.checkCancellation()` before and after suspension
- [ ] `[weak self]` captures in task closures
- [ ] CancellationError handled separately from other errors
- [ ] `isLoading` set to false in all paths

### Service Layer
- [ ] ID captured before suspension points
- [ ] Fresh entity fetched after suspension points
- [ ] Nil guards for optional metadata
- [ ] Clear error types for edge cases (notFound, deleted)
- [ ] No long-lived references across await points

### Testing
- [ ] Cancellation scenarios covered
- [ ] Missing entity scenarios covered
- [ ] Concurrent operation protection verified
- [ ] CloudKit sync interference tested

---

## 7. Real-World Example: Complete Flow

Here's how all patterns work together in the Reader feature:

```swift
// 1. VIEW: Task with stable identity
struct ReaderView: View {
    @Bindable var viewModel: ReaderViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let content = viewModel.articleContent {
                ArticleContent(content: content)
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error)
            }
        }
        // Task restarts only when article ID changes
        .task(id: viewModel.article.id) {
            await viewModel.loadContent()
        }
    }
}

// 2. VIEWMODEL: Task management with cancellation
@Observable
@MainActor
final class ReaderViewModel {
    var article: Article
    var articleContent: String?
    var isLoading: Bool = false
    var errorMessage: String?

    @ObservationIgnored
    private var loadingTask: Task<Void, Never>?
    private let readerService: ReaderServiceProtocol

    func loadContent() async {
        loadingTask?.cancel()  // Cancel previous load

        isLoading = true
        errorMessage = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                let updated = try await readerService.fetchContent(
                    for: article,
                    forceRefresh: false
                )

                try Task.checkCancellation()

                article = updated
                articleContent = updated.content
            } catch is CancellationError {
                Logger.reader.debug("Load cancelled")
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }

        loadingTask = task
        await task.value
    }
}

// 3. SERVICE: Safe reentrancy handling
@MainActor
final class ReaderService: ReaderServiceProtocol {
    func fetchContent(
        for article: Article,
        forceRefresh: Bool = false
    ) async throws -> Article {
        let articleId = article.id  // Capture ID before suspension

        guard forceRefresh || article.content == nil else {
            return article
        }

        // Long suspension point
        let content = try await metadataDataSource.fetchContent(
            for: article.url,
            timeout: nil,
            forceRefresh: forceRefresh
        )

        // Re-fetch fresh reference after suspension
        let predicate = #Predicate<Article> { $0.id == articleId }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)

        guard let freshArticle = try modelContext.fetch(descriptor).first else {
            throw ReaderServiceError.articleNotFound
        }

        // Defensive merge: only update if not already set
        if freshArticle.content == nil {
            freshArticle.content = content.content
        }
        if freshArticle.author == nil, let author = content.author {
            freshArticle.author = author
        }

        try modelContext.save()
        return freshArticle
    }
}
```

---

## 8. Related Documentation

- **[ARCHITECTURE.md](../../ARCHITECTURE.md)**: High-level system design
- **[swiftdata-cloudkit-unique-constraints.md](./swiftdata-cloudkit-unique-constraints.md)**: Preventing CloudKit sync conflicts
- **[CLAUDE.md](../../CLAUDE.md)**: Development patterns and guidelines

---

## 9. Lessons Learned

### Why This Bug Was Hard to Diagnose

1. **No logs at ViewModel level**: Only ContentDataSource had logging
2. **Intermittent nature**: Only reproduced with exact timing of CloudKit sync
3. **App restart masks issue**: Fresh ModelContext avoided reentrancy problems
4. **Multiple root causes**: Problem involved View, ViewModel, Service, and SwiftData actor boundaries

### Prevention Going Forward

1. **Always log at ViewModel level**: Critical for async debugging
2. **Use explicit task cancellation**: Don't rely on view identity alone
3. **Re-fetch after suspension**: Standard practice for SwiftData services
4. **Test CloudKit scenarios**: Simulate sync during async operations

---

## 10. Summary

The pattern to remember:

```swift
// VIEW: Stable identity
.task(id: viewModel.article.id) { await viewModel.loadContent() }

// VIEWMODEL: Task management
@ObservationIgnored
private var loadingTask: Task<Void, Never>?

func loadContent() async {
    loadingTask?.cancel()
    let task = Task { [weak self] in
        try Task.checkCancellation()
        let result = try await service.fetch()
        try Task.checkCancellation()
        self?.property = result
    }
    loadingTask = task
}

// SERVICE: Re-fetch after suspension
let id = entity.id
let data = try await fetch()  // Suspension point
let fresh = try refetch(id: id)  // Re-fetch here
fresh.data = data
```

Follow this pattern to prevent race conditions with CloudKit sync and async operations.
