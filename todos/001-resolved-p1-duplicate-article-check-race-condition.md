---
status: resolved
priority: p1
issue_id: "001"
tags: [code-review, data-integrity, race-condition, cloudkit]
dependencies: []
resolved_date: 2026-01-30
---

# Duplicate Article Check Not Race-Safe with CloudKit Sync

## Problem Statement

The duplicate URL check and article insertion are not atomic operations. When CloudKit syncs an article from another device between the `articleExists()` check and `modelContext.insert()`, duplicate articles can be created in the database.

**Why it matters:** Users will see the same article multiple times in their reading list, causing confusion and data inconsistency across devices.

## Findings

### Evidence

**File:** `Luego/Features/Sharing/Services/SharingService.swift` (lines 36-39)
```swift
if articleExists(for: validatedURL) {
    Logger.sharing.debug("Skipping duplicate URL: \(validatedURL.absoluteString)")
    continue
}
// Gap here where CloudKit sync could insert same URL
```

**File:** `Luego/Features/ReadingList/Services/ArticleService.swift` (lines 92-94)
```swift
if let existingArticle = findExistingArticle(for: ephemeralArticle.url) {
    return existingArticle
}
// Gap here where CloudKit sync could insert same URL
```

### Race Condition Scenario

1. Device A checks if URL exists (returns false)
2. Device B adds same URL via CloudKit sync (inserts record)
3. Device A inserts article (duplicate now exists)
4. User sees same article twice in reading list

## Proposed Solutions

### Option A: Add Unique Constraint ~~(Recommended)~~ ❌ NOT COMPATIBLE WITH CLOUDKIT

Add `@Attribute(.unique)` to the URL field in the Article model.

**⚠️ INCOMPATIBLE WITH CLOUDKIT SYNC**: SwiftData's `@Attribute(.unique)` constraint cannot be used with CloudKit because:
1. CloudKit doesn't support database-level unique constraints
2. Schema migrations fail when adding uniqueness to CloudKit-synced data
3. `ModelContainer` creation throws `fatalError` on app launch

**Pros:**
- Database-level enforcement prevents duplicates
- Simple implementation
- Works across all code paths

**Cons:**
- ❌ **Does not work with CloudKit sync**
- Requires handling constraint violation errors
- May need migration for existing data

**Effort:** Small
**Risk:** ~~Low~~ **HIGH - causes app crash with CloudKit**

### Option B: Transaction-Based Check-and-Insert

Wrap the existence check and insert in a database transaction.

**Pros:**
- Provides atomicity for the operation
- No schema changes required

**Cons:**
- More complex implementation
- May not fully solve CloudKit sync race

**Effort:** Medium
**Risk:** Medium

## Recommended Action

Use **application-level duplicate checks** with **graceful error handling** as defense-in-depth:
1. Check for existing article before inserting (`findExistingArticle()` / `articleExists()`)
2. Wrap insert/save in try-catch with rollback
3. On any error, attempt to return existing article if found

**Note:** Option A (`@Attribute(.unique)`) is NOT compatible with CloudKit sync.

## Technical Details

**Affected Files:**
- `Luego/Core/Models/Article.swift`
- `Luego/Features/Sharing/Services/SharingService.swift`
- `Luego/Features/ReadingList/Services/ArticleService.swift`

**Components:** SwiftData Model, ArticleService, SharingService

## Acceptance Criteria

- [x] ~~`Article.url` has `@Attribute(.unique)` constraint~~ (NOT compatible with CloudKit)
- [x] Application-level duplicate checks before insert
- [x] Error handling with rollback and existing article lookup as fallback
- [x] Tests verify duplicate prevention via fast-path check

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by data-integrity-guardian agent |
| 2026-01-30 | Attempted Option A | Added `@Attribute(.unique)` to Article.url - **CAUSED APP CRASH** |
| 2026-01-30 | Reverted unique constraint | **CRITICAL LEARNING:** `@Attribute(.unique)` is incompatible with CloudKit sync. CloudKit doesn't support database-level unique constraints, and schema migration fails with `fatalError` on `ModelContainer` creation |
| 2026-01-30 | Final implementation | Kept application-level duplicate checks (`findExistingArticle()`) with graceful error handling (try-catch with rollback) as defense-in-depth. Added tests for duplicate prevention via fast-path. |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- [SwiftData Unique Constraints](https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:))
