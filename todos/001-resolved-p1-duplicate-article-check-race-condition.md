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

### Option A: Add Unique Constraint (Recommended)

Add `@Attribute(.unique)` to the URL field in the Article model.

**Pros:**
- Database-level enforcement prevents duplicates
- Simple implementation
- Works across all code paths

**Cons:**
- Requires handling constraint violation errors
- May need migration for existing data

**Effort:** Small
**Risk:** Low

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

Implement Option A - add `@Attribute(.unique)` to `Article.url` and handle `NSConstraintConflictException` gracefully.

## Technical Details

**Affected Files:**
- `Luego/Core/Models/Article.swift`
- `Luego/Features/Sharing/Services/SharingService.swift`
- `Luego/Features/ReadingList/Services/ArticleService.swift`

**Components:** SwiftData Model, ArticleService, SharingService

## Acceptance Criteria

- [x] `Article.url` has `@Attribute(.unique)` constraint
- [x] Constraint violation errors are caught and handled gracefully
- [x] No duplicate articles can be created via any code path
- [x] Tests verify duplicate prevention

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by data-integrity-guardian agent |
| 2026-01-30 | Implemented Option A | Added `@Attribute(.unique)` to Article.url, updated ArticleService and SharingService to handle constraint violations gracefully with rollback and existing article lookup, added tests for duplicate prevention |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- [SwiftData Unique Constraints](https://developer.apple.com/documentation/swiftdata/attribute(_:originalname:hashmodifier:))
