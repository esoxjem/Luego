---
title: Fix race condition causing stuck spinner when opening CloudKit-synced articles
category: integration-issues
tags: [swiftui, swiftdata, cloudkit, concurrency, race-condition, task-lifecycle, actor-reentrancy]
module: Reader
symptoms:
  - Reader displays endless loading spinner when opening articles synced from CloudKit
  - Content never loads despite successful sync from iCloud
  - Issue occurs intermittently depending on timing of CloudKit sync and UI updates
created: 2026-01-31
---

# Race Condition: Stuck Spinner When Opening CloudKit-Synced Articles

## Problem Summary

When opening an article that was synced from CloudKit, the reader would sometimes get stuck with an endless spinner. No loading logs appeared, and the content never loaded. After app restart, the article loaded fine.

## Root Cause

The bug was caused by a **race condition between SwiftUI's `.task` modifier and CloudKit sync updates**, manifesting through three interconnected issues:

### Issue 1: SwiftUI Task Without Identity

```swift
// BEFORE - Task could restart unpredictably
.task {
    await viewModel.loadContent()
}
```

Without an explicit `id:` parameter, SwiftUI may restart the task in certain view identity scenarios. When CloudKit updates the `Article` via `@Observable`, there's no automatic cancellation of the previous task, potentially leading to concurrent executions or missed loads.

### Issue 2: No Concurrent Load Protection

```swift
// BEFORE - Race window between guard and state mutation
func loadContent() async {
    guard articleContent == nil else { return }  // Weak guard
    isLoading = true
    // ... long async operation
}
```

Problems:
- Race window between guard check and `isLoading = true`
- No `Task.checkCancellation()` during long-running fetch
- `@Observable` mutation during suspension triggers view updates

### Issue 3: Actor Reentrancy in ReaderService

```swift
// BEFORE - Stale reference after suspension
func fetchContent(for article: Article, ...) async throws -> Article {
    let content = try await metadataDataSource.fetchContent(...)  // Suspension point
    article.content = content.content  // article may be stale!
}
```

After the suspension point, the `article` reference may have been updated by CloudKit sync, but the method writes to the potentially stale reference.

### Why It Worked After App Restart

After restarting:
- Fresh `ModelContext` with no pending syncs
- No concurrent CloudKit updates happening
- Article instance is stable (no in-flight mutations)
- Single clean load path without race conditions

## Solution

### Fix 1: Add Task ID to ReaderView

**File**: `Luego/Features/Reader/Views/ReaderView.swift`

```swift
// AFTER - Task scoped to article identity
.task(id: viewModel.article.id) {
    await viewModel.loadContent()
}
```

Using `article.id` ensures:
- Task only restarts when viewing a different article
- CloudKit sync updates to the same article won't restart the task
- Task cancellation propagates automatically when the ID changes

### Fix 2: Add Task Cancellation to ReaderViewModel

**File**: `Luego/Features/Reader/Views/ReaderViewModel.swift`

```swift
@ObservationIgnored
private var loadingTask: Task<Void, Never>?

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
            // Silently handle - task was cancelled, no error to show
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    loadingTask = task
    await task.value
}
```

Key changes:
- `@ObservationIgnored` prevents unnecessary view invalidation when task reference changes
- `loadingTask` property tracks and cancels in-flight loads
- `[weak self]` capture prevents retain cycles
- `Task.checkCancellation()` before and after async work
- Separate `CancellationError` handling (doesn't show error UI)
- `isLoading = false` guaranteed in all paths

### Fix 3: Fix Actor Reentrancy in ReaderService

**File**: `Luego/Features/Reader/Services/ReaderService.swift`

```swift
func fetchContent(for article: Article, forceRefresh: Bool = false) async throws -> Article {
    let articleId = article.id  // Capture ID before suspension

    guard forceRefresh || article.content == nil else {
        return article
    }

    let content = try await metadataDataSource.fetchContent(for: article.url, timeout: nil, forceRefresh: forceRefresh)

    // Re-fetch fresh article from ModelContext after suspension
    let predicate = #Predicate<Article> { $0.id == articleId }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)

    guard let freshArticle = try modelContext.fetch(descriptor).first else {
        throw ReaderServiceError.articleNotFound
    }

    // Use nil guards to prevent overwriting CloudKit-synced data
    if freshArticle.content == nil {
        freshArticle.content = content.content
    }

    if freshArticle.author == nil, let author = content.author {
        freshArticle.author = author
    }
    // ... similar guards for other fields

    try modelContext.save()
    return freshArticle
}
```

Key changes:
- Capture `articleId` before any suspension point
- Re-fetch from `ModelContext` after suspension to get fresh instance
- Nil guards prevent overwriting CloudKit-synced data
- New `ReaderServiceError.articleNotFound` for deleted entities

### Fix 4: Add Reader Logger Category

**File**: `Luego/Core/Logging/Logger.swift`

```swift
static let reader = Logger(category: "Reader")
```

Enables targeted debugging for reader-related operations.

## Prevention Strategies

### SwiftUI Task Lifecycle Best Practices

| Scenario | Use | Example ID |
|----------|-----|------------|
| Per-item loading | `.task(id:)` | `item.id` |
| One-time initialization | `.task` | N/A |
| Observable model changes | `.task(id:)` | Model's stable identifier |

### @Observable + Task Management Pattern

```swift
@Observable
@MainActor
final class SomeViewModel {
    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    func performWork() async {
        activeTask?.cancel()

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()
                // ... async work
                try Task.checkCancellation()
                // ... update state
            } catch is CancellationError {
                // Handle gracefully
            } catch {
                // Handle error
            }
        }

        activeTask = task
        await task.value
    }
}
```

### SwiftData Actor Reentrancy Checklist

Before any suspension point in a `@MainActor` service:
- [ ] Capture stable identifiers (IDs, not object references)
- [ ] After suspension, re-fetch from ModelContext using captured ID
- [ ] Use nil guards when updating to prevent overwriting sync'd data
- [ ] Handle the case where entity was deleted during suspension

### CloudKit Sync Defensive Patterns

```swift
// Defensive content update - don't overwrite sync'd data
if freshArticle.content == nil {
    freshArticle.content = fetchedContent
}

// Handle deletion during async operation
guard let entity = try modelContext.fetch(descriptor).first else {
    throw ServiceError.entityNotFound
}
```

## Test Cases

### Cancellation Handling Test

```swift
@Test("loadContent handles cancellation gracefully")
func loadContentHandlesCancellationGracefully() async {
    mockReaderService.shouldThrowCancellationError = true

    await sut.loadContent()

    #expect(sut.errorMessage == nil)  // No error shown for cancellation
    #expect(sut.isLoading == false)   // Loading state cleaned up
}
```

### Entity Not Found Test

```swift
@Test("fetchContent throws when article deleted during fetch")
func fetchContentThrowsWhenArticleDeleted() async throws {
    // Configure mock to delete article during fetch
    mockMetadataDataSource.onFetch = { [modelContext, article] in
        modelContext.delete(article)
        try modelContext.save()
    }

    await #expect(throws: ReaderServiceError.self) {
        try await sut.fetchContent(for: article, forceRefresh: false)
    }
}
```

## Files Changed

| File | Change |
|------|--------|
| `Luego/Features/Reader/Views/ReaderView.swift` | Added `.task(id:)` parameter |
| `Luego/Features/Reader/Views/ReaderViewModel.swift` | Added task tracking with cancellation |
| `Luego/Features/Reader/Services/ReaderService.swift` | Fixed actor reentrancy, added content guard |
| `Luego/Core/Logging/Logger.swift` | Added `reader` category |
| `LuegoTests/.../ReaderViewModelTests.swift` | Added cancellation test |
| `LuegoTests/.../MockReaderService.swift` | Added cancellation error support |

## Related Documentation

- [observable-nonisolated-unsafe-conflict.md](../build-errors/observable-nonisolated-unsafe-conflict.md) - @Observable + Task property patterns
- [swiftdata-unique-constraint-cloudkit-sync-crash.md](../database-issues/swiftdata-unique-constraint-cloudkit-sync-crash.md) - CloudKit sync fundamentals
- [agent_docs/reader.md](../../../agent_docs/reader.md) - Reader feature architecture
- [2026-01-31-fix-reader-loading-race-condition-plan.md](../../plans/2026-01-31-fix-reader-loading-race-condition-plan.md) - Original implementation plan

## Related Commits

- `488a633` - fix(reader): resolve race condition causing stuck spinner on CloudKit-synced articles
- `359af0f` - fix(sync): resolve @Observable macro conflict with nonisolated(unsafe)
- `4760776` - refactor(reader): address PR #40 review findings
