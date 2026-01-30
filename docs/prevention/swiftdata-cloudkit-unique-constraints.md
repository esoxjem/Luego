# SwiftData + CloudKit: Unique Constraints Prevention Guide

## Overview

SwiftData's `@Attribute(.unique)` constraint is **incompatible with CloudKit sync**. Attempting to use unique constraints on models with CloudKit sync enabled will cause the app to crash at launch with `ModelContainer` initialization failure.

This guide provides prevention strategies, best practices, and alternative approaches for maintaining data uniqueness in CloudKit-synced SwiftData models.

---

## Critical Incompatibility

### Why This Matters

- **CloudKit is a distributed database** that doesn't support database-level unique constraints
- **Schema migrations fail** when adding `@Attribute(.unique)` to CloudKit-synced models
- **App crashes at startup** with `fatalError` during `ModelContainer` creation
- **No graceful degradation** - the app simply won't launch

### Example Failure Scenario

```swift
@Model
final class Article {
    var id: UUID = UUID()
    @Attribute(.unique) var url: URL  // FATAL ERROR with CloudKit sync!
    var title: String = ""
}

// In LuegoApp.swift
let modelConfiguration = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .private("iCloud.com.example.App")
)
do {
    return try ModelContainer(for: schema, configurations: [modelConfiguration])
} catch {
    fatalError("Could not create ModelContainer: \(error)")
    // Will crash here with CloudKit + @Attribute(.unique)
}
```

---

## Prevention Checklist

Use this checklist when designing CloudKit-synced models to avoid this issue:

- [ ] **Never use `@Attribute(.unique)` on CloudKit-synced models**
  - CloudKit doesn't support database-level uniqueness constraints
  - Consider this a hard architectural rule

- [ ] **Identify fields that need uniqueness semantics**
  - Document which fields should be logically unique (e.g., article URL)
  - Note that database-level enforcement won't be available

- [ ] **Implement application-level duplicate detection**
  - Add fast-path checks before insert operations
  - Query for existing records by the "unique" field

- [ ] **Add graceful error handling with fallback logic**
  - Wrap insert/save operations in try-catch blocks
  - On constraint-like errors, query for existing record
  - Return existing record instead of failing

- [ ] **Validate at the service layer**
  - Implement duplicate checks in CRUD service methods
  - Make these checks mandatory, not optional

- [ ] **Document the uniqueness requirement**
  - Add comments explaining why a field should be unique
  - Reference this prevention guide
  - Note the workaround approach used

- [ ] **Test duplicate prevention scenarios**
  - Write tests that verify duplicates are prevented
  - Test the fast-path check (pre-insert detection)
  - Test the error fallback (finding existing record on insert failure)

- [ ] **Consider data validation on app launch**
  - Periodically check for duplicate records in background
  - Implement cleanup logic if duplicates somehow occur

---

## Best Practices for CloudKit-Synced Models

### 1. Design Models Without Unique Constraints

```swift
@Model
final class Article {
    @Attribute(.unique) private(set) var id: UUID = UUID()  // OK: synthetic ID
    // ❌ DON'T DO THIS:
    // @Attribute(.unique) var url: URL

    var url: URL  // OK: no constraint, but we'll check uniqueness manually
    var title: String = ""
    var savedDate: Date = Date()
}
```

**Why:** The synthetic `id` is generated locally and never conflicts. Business keys like URLs can't use database constraints.

### 2. Implement Duplicate Detection at Service Layer

```swift
@MainActor
final class ArticleService {
    private let modelContext: ModelContext

    // Fast-path check BEFORE inserting
    private func findExistingArticle(for url: URL) -> Article? {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    // Always check for duplicates first
    func save(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
        // Fast-path: check if already exists
        if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
            return existingArticle
        }

        // Create and insert new article
        let article = Article(url: ephemeralArticle.url, title: ephemeralArticle.title)
        modelContext.insert(article)
        try modelContext.save()
        return article
    }
}
```

### 3. Wrap Insert Operations with Error Recovery

```swift
func save(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
    if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
        return existingArticle
    }

    let article = Article(url: ephemeralArticle.url, title: ephemeralArticle.title)

    do {
        modelContext.insert(article)
        try modelContext.save()
        return article
    } catch {
        // Rollback failed insert
        modelContext.rollback()

        // Try to recover by finding the existing article
        // (another device may have synced the same URL via CloudKit)
        if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
            Logger.article.debug("Duplicate detected via CloudKit sync: \(ephemeralArticle.url.absoluteString)")
            return existingArticle
        }

        // If still no existing article, it's a real error
        throw error
    }
}
```

### 4. Document Uniqueness Requirements Clearly

```swift
/// Stores articles for the reading list with CloudKit sync.
///
/// **Uniqueness Guarantee:**
/// While `url` is not enforced with `@Attribute(.unique)` (incompatible with CloudKit),
/// the service layer ensures at most one article per URL through:
/// 1. Fast-path duplicate check before insert (findExistingArticle)
/// 2. Error recovery on insert failure (fallback to existing record)
///
/// See: docs/prevention/swiftdata-cloudkit-unique-constraints.md
@Model
final class Article {
    var id: UUID = UUID()
    var url: URL
    var title: String
    // ...
}
```

### 5. Validate on App Launch

```swift
@MainActor
final class DatabaseHealthCheck {
    private let modelContext: ModelContext

    func detectDuplicateURLs() -> [URL] {
        let allArticles = (try? modelContext.fetch(FetchDescriptor<Article>())) ?? []
        let urlCounts = Dictionary(grouping: allArticles, by: { $0.url })
        return urlCounts.filter { $0.value.count > 1 }.keys.map { $0 }
    }

    func reportDuplicates() async {
        let duplicates = detectDuplicateURLs()
        if !duplicates.isEmpty {
            Logger.error("Found \(duplicates.count) duplicate URLs in database")
            // Consider: alert user, merge records, or clean up
        }
    }
}
```

---

## Warning Signs: When You Might Have This Issue

### Before Code Review

- [ ] Adding `@Attribute(.unique)` to any field in a CloudKit-synced model
- [ ] Enabling CloudKit sync on a model that already has unique constraints
- [ ] Receiving schema migration errors during `ModelContainer` initialization
- [ ] The app crashes at launch with `fatalError` in the model initialization code

### In Code Review

Look for these patterns that indicate the issue:

```swift
// RED FLAG #1: Unique constraint on CloudKit model
@Model
final class Article {
    @Attribute(.unique) var url: URL  // ❌ INCOMPATIBLE WITH CLOUDKIT
}

// RED FLAG #2: Relying solely on database constraints for distributed data
// CloudKit doesn't support database-level uniqueness, so this won't work

// RED FLAG #3: Missing duplicate detection before insert
let article = Article(url: url, title: title)
modelContext.insert(article)  // ❌ No prior check, race condition possible
try modelContext.save()

// RED FLAG #4: No error handling for constraint violations
// (Even though constraints won't work, the pattern shows weak intent)
do {
    modelContext.insert(article)
    try modelContext.save()
} catch {
    throw error  // ❌ No fallback to existing record
}
```

### At Runtime

- App crashes at startup with `ModelContainer` initialization error
- User sees "app won't open" or "unexpected error" on first launch
- CloudKit sync works on one device but app crashes on other devices
- Schema migration errors in console logs

---

## Alternative Approaches for Maintaining Uniqueness

### Approach 1: Application-Level Fast-Path Check (RECOMMENDED)

**When to use:** Most common case - checking for duplicates before insert

```swift
func save(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
    // Fast-path: Query for existing article
    if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
        return existingArticle
    }

    let article = Article(url: ephemeralArticle.url, title: ephemeralArticle.title)
    modelContext.insert(article)
    try modelContext.save()
    return article
}
```

**Pros:**
- Simple and efficient
- Avoids duplicate inserts in normal operation
- Works across all devices

**Cons:**
- Race condition possible if two devices insert simultaneously (but recoverable with Approach 2)
- Requires discipline to always check first

**Effort:** Small | **Risk:** Low

---

### Approach 2: Error Recovery with Fallback (RECOMMENDED)

**When to use:** When you need robustness against race conditions

```swift
func save(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
    if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
        return existingArticle
    }

    let article = Article(url: ephemeralArticle.url, title: ephemeralArticle.title)

    do {
        modelContext.insert(article)
        try modelContext.save()
        return article
    } catch {
        modelContext.rollback()

        // Recovery: article may have been synced from CloudKit
        if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
            return existingArticle
        }

        throw error
    }
}
```

**Pros:**
- Handles race conditions where CloudKit syncs during the gap
- Graceful recovery instead of failure
- Provides logging for debugging

**Cons:**
- Slightly more complex logic
- Requires try-catch in multiple places

**Effort:** Small-Medium | **Risk:** Low

---

### Approach 3: Transaction-Based Check-and-Insert

**When to use:** When atomic operations are critical (rarely needed for CloudKit)

```swift
func save(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
    // Note: SwiftData doesn't have explicit transaction API
    // This approach would require database-level transactions
    // Generally not recommended for CloudKit-synced data

    // Instead, use Approaches 1-2 above
}
```

**Pros:**
- True atomicity if available

**Cons:**
- SwiftData doesn't provide explicit transaction API
- Not applicable to CloudKit architecture
- Over-engineered for distributed database

**Effort:** N/A | **Risk:** Not recommended

---

### Approach 4: Client-Side Merge Strategy

**When to use:** When duplicates can occur and need intelligent handling

```swift
@MainActor
final class DuplicateMergeService {
    private let modelContext: ModelContext

    /// Finds duplicate articles by URL and merges them into one
    func mergeDuplicates(for url: URL) async throws {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        let articles = try modelContext.fetch(descriptor)

        guard articles.count > 1 else { return }

        // Keep the oldest (first saved) article
        let primary = articles.min { $0.savedDate < $1.savedDate } ?? articles[0]

        // Merge state from newer articles into primary
        for article in articles where article.id != primary.id {
            if article.isFavorite {
                primary.isFavorite = true
            }
            if !article.isArchived && primary.isArchived {
                primary.isArchived = false
            }
            if article.readPosition > primary.readPosition {
                primary.readPosition = article.readPosition
            }

            modelContext.delete(article)
        }

        try modelContext.save()
    }
}
```

**Pros:**
- Recovers from duplicates intelligently
- Preserves user state across devices
- Good for multi-device scenarios

**Cons:**
- Complex merge logic needed
- Should be preventive, not primary solution
- Can mask other issues

**Effort:** Medium-Large | **Risk:** Medium

---

## Real-World Example: Luego Article Service

The Luego app implements Approaches 1 and 2 in its `ArticleService`:

**File:** `/Luego/Features/ReadingList/Services/ArticleService.swift`

```swift
@MainActor
final class ArticleService {
    private let modelContext: ModelContext

    // Fast-path duplicate check
    private func findExistingArticle(for url: URL) -> Article? {
        let predicate = #Predicate<Article> { $0.url == url }
        let descriptor = FetchDescriptor<Article>(predicate: predicate)
        return try? modelContext.fetch(descriptor).first
    }

    // Approach 1 + 2: Check then insert with error recovery
    func saveEphemeralArticle(_ ephemeralArticle: EphemeralArticle) async throws -> Article {
        // Fast-path check
        if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
            return existingArticle
        }

        let article = Article(
            url: ephemeralArticle.url,
            title: ephemeralArticle.title
        )

        do {
            modelContext.insert(article)
            try modelContext.save()
            return article
        } catch {
            // Error recovery fallback
            modelContext.rollback()
            if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
                Logger.article.debug("Duplicate detected via constraint: \(ephemeralArticle.url.absoluteString)")
                return existingArticle
            }
            throw error
        }
    }
}
```

This pattern is also used in `SharingService.swift` for consistency.

---

## Testing Strategies

### Test 1: Fast-Path Duplicate Prevention

```swift
@Suite
struct ArticleServiceTests {
    @Test("Should return existing article without creating duplicate")
    @MainActor
    func fastPathDuplicatePrevention() async throws {
        let url = URL(string: "https://example.com/article")!

        // Insert first article
        let article1 = try await service.saveEphemeralArticle(
            EphemeralArticle(url: url, title: "Test")
        )

        // Try to save same URL again
        let article2 = try await service.saveEphemeralArticle(
            EphemeralArticle(url: url, title: "Test 2")
        )

        // Should return the same article
        #expect(article1.id == article2.id)
    }
}
```

### Test 2: Error Recovery on Insert Failure

```swift
@Test("Should recover from insert failure by finding existing article")
@MainActor
func errorRecoveryOnInsertFailure() async throws {
    let url = URL(string: "https://example.com/article")!

    // Simulate another device syncing the same article
    let syncedArticle = Article(url: url, title: "Original")
    modelContext.insert(syncedArticle)
    try modelContext.save()

    // Service attempts to save the same URL
    let article = try await service.saveEphemeralArticle(
        EphemeralArticle(url: url, title: "Our Copy")
    )

    // Should return the synced article, not throw
    #expect(article.id == syncedArticle.id)
}
```

### Test 3: Database Health Check

```swift
@Test("Should detect duplicate URLs on app launch")
@MainActor
func detectDuplicatesOnAppLaunch() async throws {
    let url = URL(string: "https://example.com/article")!

    // Manually create duplicates (simulating sync issue)
    let dup1 = Article(url: url, title: "Dup 1")
    let dup2 = Article(url: url, title: "Dup 2")
    modelContext.insert(dup1)
    modelContext.insert(dup2)
    try modelContext.save()

    // Health check should find them
    let duplicates = healthCheck.detectDuplicateURLs()
    #expect(duplicates.contains(url))
}
```

---

## Debugging: If You Still Get Crashes

If the app crashes with `ModelContainer` initialization error:

1. **Check model definitions** - Search for `@Attribute(.unique)` in all `@Model` classes
   ```bash
   grep -r "@Attribute(.unique)" Luego/
   ```

2. **Verify CloudKit configuration** - Check if `cloudKitDatabase` is set
   ```swift
   let modelConfiguration = ModelConfiguration(
       schema: schema,
       cloudKitDatabase: .private("iCloud.com.example.App")  // ← Is this set?
   )
   ```

3. **Review recent model changes** - Check git diff for newly added unique constraints
   ```bash
   git diff HEAD -- "**/Models/*.swift"
   ```

4. **Check for schema migrations** - Xcode may be trying to migrate old schema
   - Delete the app from simulator: `xcrun simctl erase all`
   - Clear derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData`
   - Rebuild and test

5. **Review error message carefully** - The crash will mention:
   - "unique constraint" or "schema migration"
   - "CloudKit" or "iCloud"
   - "ModelContainer" initialization

---

## Key Takeaways

1. **Never use `@Attribute(.unique)` with CloudKit sync** - It will crash the app
2. **Always implement application-level duplicate detection** - Use fast-path checks before insert
3. **Wrap inserts with error recovery** - Fallback to finding existing record on error
4. **Document the uniqueness requirement** - Add comments explaining why fields should be unique
5. **Test duplicate scenarios** - Verify fast-path and error recovery both work
6. **Consider data validation on app launch** - Periodically check for duplicates

---

## References

- **Related Issue:** `/todos/001-resolved-p1-duplicate-article-check-race-condition.md`
- **SwiftData Documentation:** https://developer.apple.com/documentation/swiftdata/
- **CloudKit Best Practices:** https://developer.apple.com/documentation/cloudkit/
- **Luego Article Service:** `/Luego/Features/ReadingList/Services/ArticleService.swift`
- **Luego Sharing Service:** `/Luego/Features/Sharing/Services/SharingService.swift`
