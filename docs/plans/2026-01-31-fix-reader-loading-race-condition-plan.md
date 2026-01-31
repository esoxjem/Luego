# Fix Reader Loading Race Condition

## Problem Statement

When opening an article that was synced from CloudKit (upstream), the reader sometimes gets stuck with an endless spinner. No loading logs appear. After app restart, the article loads fine with logs appearing as expected.

## Root Cause Analysis

The bug is caused by a **race condition between SwiftUI's `.task` modifier and CloudKit sync updates**.

### Issue 1: `.task` Without `id:` Parameter

**File**: `ReaderView.swift:50-52`

```swift
.task {
    await viewModel.loadContent()
}
```

Without an explicit `id:` parameter, SwiftUI may restart the task in certain view identity scenarios. When CloudKit updates the `Article` via `@Observable`, there's no automatic cancellation of the previous task, potentially leading to concurrent executions.

### Issue 2: No Concurrent Load Protection

**File**: `ReaderViewModel.swift:24-38`

```swift
func loadContent() async {
    guard articleContent == nil else { return }  // Weak guard
    isLoading = true
    // ... long async operation
}
```

**Problems**:
1. Race window between guard check and `isLoading = true`
2. No `Task.checkCancellation()` during long-running fetch
3. `@Observable` mutation (`article = updatedArticle`) during suspension triggers view updates

### Issue 3: Actor Reentrancy in ReaderService

**File**: `ReaderService.swift:19-39`

The `fetchContent` method has a suspension point during `metadataDataSource.fetchContent()`. After resuming, the article state may have changed due to CloudKit sync, but the method writes to the potentially stale `article` reference.

### Issue 4: No Logging in Reader Components

The `ReaderService` and `ReaderViewModel` have no logging, making it impossible to diagnose when loading gets stuck. Only `ContentDataSource` logs, which is never reached when the race condition occurs at the ViewModel level.

## Why It Works After App Restart

After restarting:
- Fresh `ModelContext` with no pending syncs
- No concurrent CloudKit updates happening
- Article instance is stable (no in-flight mutations)
- Single clean load path without race conditions

## Implementation Plan

### Step 1: Add Task ID to ReaderView

**File**: `Luego/Features/Reader/Views/ReaderView.swift`

Change line 50-52 from:
```swift
.task {
    await viewModel.loadContent()
}
```

To:
```swift
.task(id: viewModel.article.id) {
    await viewModel.loadContent()
}
```

**Rationale**: Using `article.id` ensures the task only restarts when viewing a different article. CloudKit sync updates to the same article won't restart the task since the ID stays the same. Task cancellation propagates automatically when the ID changes.

### Step 2: Add Task Cancellation to ReaderViewModel

**File**: `Luego/Features/Reader/Views/ReaderViewModel.swift`

Add a `loadingTask` property and refactor `loadContent()`:

```swift
@Observable
@MainActor
final class ReaderViewModel {
    var article: Article
    var articleContent: String?
    var isLoading: Bool
    var errorMessage: String?

    private var loadingTask: Task<Void, Never>?
    private let readerService: ReaderServiceProtocol

    init(article: Article, readerService: ReaderServiceProtocol) {
        self.article = article
        self.articleContent = article.content
        self.isLoading = article.content == nil
        self.readerService = readerService
    }

    func loadContent() async {
        guard articleContent == nil else { return }

        loadingTask?.cancel()

        isLoading = true
        errorMessage = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                let updatedArticle = try await readerService.fetchContent(for: article, forceRefresh: false)

                try Task.checkCancellation()

                article = updatedArticle
                articleContent = updatedArticle.content
            } catch is CancellationError {
                Logger.reader.debug("loadContent cancelled for article \(article.id)")
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }

        loadingTask = task
        await task.value
    }

    func refreshContent() async {
        loadingTask?.cancel()

        isLoading = true
        errorMessage = nil

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                try Task.checkCancellation()

                let updatedArticle = try await readerService.fetchContent(for: article, forceRefresh: true)

                try Task.checkCancellation()

                article = updatedArticle
                articleContent = updatedArticle.content
            } catch is CancellationError {
                Logger.reader.debug("refreshContent cancelled for article \(article.id)")
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }

        loadingTask = task
        await task.value
    }

    func updateReadPosition(_ position: Double) async {
        let clampedPosition = max(0.0, min(1.0, position))
        article.readPosition = clampedPosition

        do {
            try await readerService.updateReadPosition(articleId: article.id, position: clampedPosition)
        } catch {
            errorMessage = "Failed to save read position: \(error.localizedDescription)"
        }
    }
}
```

**Key changes**:
1. `loadingTask` property to track and cancel in-flight loads
2. `[weak self]` capture to prevent retain cycles
3. `Task.checkCancellation()` before and after async work
4. Separate `CancellationError` handling (doesn't show error UI)
5. `isLoading = false` guaranteed in all paths

### Step 3: Add Reader Logger Category

**File**: `Luego/Core/Logging/Logger.swift`

Add a new logger category:
```swift
extension Logger {
    static let reader = Logger(category: "Reader")
}
```

### Step 4: Add Logging to ReaderViewModel

**File**: `Luego/Features/Reader/Views/ReaderViewModel.swift`

Add strategic logging:

```swift
func loadContent() async {
    Logger.reader.debug("loadContent() called for article \(article.id)")

    guard articleContent == nil else {
        Logger.reader.debug("Content already loaded, skipping")
        return
    }

    loadingTask?.cancel()
    Logger.reader.debug("Starting content load")

    // ... rest of method

    // In success path:
    Logger.reader.debug("Content loaded successfully")

    // In cancellation path:
    Logger.reader.debug("loadContent cancelled")

    // In error path:
    Logger.reader.error("loadContent failed: \(error.localizedDescription)")
}
```

### Step 5: Fix Actor Reentrancy in ReaderService

**File**: `Luego/Features/Reader/Services/ReaderService.swift`

Re-fetch the article from ModelContext after suspension to ensure fresh state:

```swift
func fetchContent(for article: Article, forceRefresh: Bool = false) async throws -> Article {
    let articleId = article.id

    guard forceRefresh || article.content == nil else {
        return article
    }

    let content = try await metadataDataSource.fetchContent(for: article.url, timeout: nil, forceRefresh: forceRefresh)

    let predicate = #Predicate<Article> { $0.id == articleId }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)

    guard let freshArticle = try modelContext.fetch(descriptor).first else {
        throw ReaderServiceError.articleNotFound
    }

    freshArticle.content = content.content

    if freshArticle.author == nil, let author = content.author {
        freshArticle.author = author
    }
    if freshArticle.wordCount == nil, let wordCount = content.wordCount {
        freshArticle.wordCount = wordCount
    }
    if freshArticle.thumbnailURL == nil, let thumbnailURL = content.thumbnailURL {
        freshArticle.thumbnailURL = thumbnailURL
    }

    try modelContext.save()
    return freshArticle
}
```

Also add `ReaderServiceError` enum:

```swift
enum ReaderServiceError: Error, LocalizedError {
    case articleNotFound

    var errorDescription: String? {
        switch self {
        case .articleNotFound:
            return "Article not found in database"
        }
    }
}
```

## Testing Plan

### Manual Testing

1. **Sync scenario**:
   - Add article on Device A
   - Wait for CloudKit sync to Device B
   - Open article on Device B immediately
   - Verify loading completes (not stuck)

2. **Rapid navigation**:
   - Quickly tap between articles in reading list
   - Verify no stuck spinners

3. **CloudKit sync during load**:
   - Open article that hasn't loaded content
   - Trigger CloudKit sync (from another device)
   - Verify loading completes

### Log Verification

After implementation, these logs should appear:
```
[Reader] loadContent() called for article <UUID>
[Reader] Starting content load
[Content] URL: example.com
[Content] SDK: Ready (v1.0, rules: 1.0)
[Content] ✓ Local SDK parsing SUCCESS
[Reader] Content loaded successfully
```

If cancellation occurs:
```
[Reader] loadContent() called for article <UUID>
[Reader] Starting content load
[Reader] loadContent cancelled for article <UUID>
```

## Files to Modify

| File | Changes |
|------|---------|
| `Luego/Features/Reader/Views/ReaderView.swift` | Add `.task(id:)` parameter |
| `Luego/Features/Reader/Views/ReaderViewModel.swift` | Add task cancellation, logging |
| `Luego/Features/Reader/Services/ReaderService.swift` | Fix reentrancy, add error enum |
| `Luego/Core/Logging/Logger.swift` | Add `reader` category |

## Rollback Plan

If issues arise, revert all changes. The original code is functional except for this specific race condition scenario.

## Success Criteria

1. No more stuck spinners when opening CloudKit-synced articles
2. Logs appear for all loading attempts
3. Cancellation works cleanly (no error messages for cancelled loads)
4. Existing functionality unchanged (force refresh, read position tracking)
