---
title: SwiftData unique constraint incompatibility with CloudKit sync
category: database-issues
tags: [swiftdata, cloudkit, constraints, crash, deduplication, ios, macos]
module: Core/Models/Article
symptoms:
  - App crashes on launch with fatalError during ModelContainer initialization
  - Crash occurs immediately when @Attribute(.unique) decorator is added
  - No error message provides guidance about CloudKit incompatibility
  - Stack trace shows failure in schema migration
root_cause: CloudKit does not support database-level unique constraints; SwiftData's @Attribute(.unique) cannot be used with CloudKit-synced models
severity: critical
date_documented: 2026-01-30
---

# SwiftData Unique Constraint Incompatibility with CloudKit Sync

## Problem Description

When attempting to add a database-level unique constraint to a SwiftData model property using `@Attribute(.unique)`, the application crashes immediately on launch with a `fatalError` during `ModelContainer` initialization.

**Exact Error Location**: `LuegoApp.swift` line 28 - `ModelContainer` creation fails

**Observable Symptoms**:
- App terminates before rendering any UI
- Crash occurs only when CloudKit sync is enabled
- Stack trace shows `_assertionFailure` in model container initialization

```swift
// This configuration causes the crash
@Model
final class Article {
    @Attribute(.unique) var url: URL  // <-- CAUSES CRASH WITH CLOUDKIT
}
```

## Investigation Steps

1. **Added unique constraint** to `Article.url` property:
   ```swift
   @Attribute(.unique) var url: URL = URL(string: "luego://placeholder")!
   ```

2. **Built and ran app** on iOS simulator - app crashed immediately

3. **Checked crash logs** - found `fatalError` at `ModelContainer` creation:
   ```
   closure #1 in variable initialization expression of LuegoApp.sharedModelContainer
   ```

4. **Identified CloudKit involvement** - the `ModelConfiguration` uses:
   ```swift
   cloudKitDatabase: .private("iCloud.com.esoxjem.Luego")
   ```

5. **Tested without CloudKit** - unique constraint works when `cloudKitDatabase` is removed

6. **Researched Apple documentation** - confirmed CloudKit doesn't support unique constraints

## Root Cause Analysis

### Why It Fails

CloudKit, Apple's cloud database service, **does not support database-level unique constraints**. When SwiftData creates a `ModelContainer` with:

1. CloudKit sync enabled via `cloudKitDatabase: .private(...)`
2. A schema containing `@Attribute(.unique)` modifiers

The schema migration system cannot reconcile these requirements because:

1. **Distributed Nature**: CloudKit is a distributed database where the same data exists on multiple devices. Enforcing uniqueness across all devices simultaneously is architecturally impossible without centralized coordination.

2. **Conflict Resolution**: CloudKit uses "last write wins" or merge policies for conflicts. Unique constraints would require rejecting valid writes, breaking the sync model.

3. **Schema Incompatibility**: The unique constraint is a SQLite-level feature that has no equivalent in CloudKit's schema system.

### Technical Details

```swift
// This works (no CloudKit)
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false
    // No cloudKitDatabase parameter
)

// This crashes (with CloudKit + unique constraint)
let modelConfiguration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    cloudKitDatabase: .private("iCloud.com.example.app")  // <-- INCOMPATIBLE
)
```

## Working Solution

### Step 1: Remove Database-Level Constraint

Remove `@Attribute(.unique)` from any property in CloudKit-synced models:

```swift
// BEFORE (causes crash)
@Model
final class Article {
    var id: UUID = UUID()
    @Attribute(.unique) var url: URL = URL(string: "luego://placeholder")!
}

// AFTER (works with CloudKit)
@Model
final class Article {
    var id: UUID = UUID()
    var url: URL = URL(string: "luego://placeholder")!  // No unique constraint
}
```

### Step 2: Implement Application-Level Duplicate Detection

Add a helper method to check for existing records before inserting:

```swift
private func findExistingArticle(for url: URL) -> Article? {
    let predicate = #Predicate<Article> { $0.url == url }
    let descriptor = FetchDescriptor<Article>(predicate: predicate)
    return try? modelContext.fetch(descriptor).first
}
```

### Step 3: Add Graceful Error Handling

Wrap insert operations with try-catch and rollback:

```swift
func addArticle(url: URL) async throws -> Article {
    // Fast-path: check for existing article first
    if let existingArticle = findExistingArticle(for: url) {
        Logger.article.debug("Duplicate detected: \(url.absoluteString)")
        return existingArticle
    }

    let article = Article(url: url, title: "...")

    // Defense-in-depth: handle race conditions
    do {
        modelContext.insert(article)
        try modelContext.save()
        return article
    } catch {
        modelContext.rollback()
        // Check again - another process might have inserted
        if let existingArticle = findExistingArticle(for: url) {
            Logger.article.debug("Duplicate detected after error: \(url.absoluteString)")
            return existingArticle
        }
        throw error
    }
}
```

### Step 4: Apply to All Insert Points

Ensure all code paths that create records use the same pattern:
- `ArticleService.addArticle()`
- `ArticleService.saveEphemeralArticle()`
- `SharingService.syncSharedArticles()`

## Prevention Checklist

- [ ] **Never use `@Attribute(.unique)`** on CloudKit-synced models
- [ ] **Implement application-level duplicate checks** before inserting
- [ ] **Add graceful error handling** with rollback as fallback
- [ ] **Document the limitation** in model comments
- [ ] **Test duplicate scenarios** in unit tests

## Best Practices for SwiftData + CloudKit

### DO:
- Use application-level queries to check for duplicates
- Implement retry logic with existing record lookup
- Log duplicate attempts for debugging
- Design for eventual consistency

### DON'T:
- Use `@Attribute(.unique)` on any synced property
- Assume inserts will fail on duplicates
- Rely on database-level constraints for data integrity
- Ignore the distributed nature of CloudKit

## Testing Strategy

```swift
@Test("addArticle returns existing article when duplicate URL is added")
func addArticleReturnsDuplicateWhenURLExists() async throws {
    let url = URL(string: "https://example.com/test")!

    let originalArticle = try await sut.addArticle(url: url)
    let duplicateArticle = try await sut.addArticle(url: url)

    #expect(duplicateArticle.id == originalArticle.id)

    let allArticles = try await sut.getAllArticles()
    #expect(allArticles.count == 1)
}
```

## Key Takeaways

1. **SwiftData `@Attribute(.unique)` is incompatible with CloudKit sync**
2. **The crash happens at app launch** during `ModelContainer` creation
3. **No clear error message** - you have to know this limitation exists
4. **Use application-level checks** instead of database constraints
5. **This affects all Apple platforms** using SwiftData + CloudKit

## Related Documentation

- [CloudKit Remote Notification Background Mode](../build-errors/cloudkit-remote-notification-background-mode.md)
- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [CloudKit Overview](https://developer.apple.com/documentation/cloudkit)

## References

- PR where issue was discovered: https://github.com/esoxjem/Luego/pull/38
- TODO tracking the fix: `todos/001-resolved-p1-duplicate-article-check-race-condition.md`
