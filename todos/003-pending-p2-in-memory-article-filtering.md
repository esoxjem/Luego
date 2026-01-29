---
status: pending
priority: p2
issue_id: "003"
tags: [code-review, performance, swiftdata]
dependencies: []
---

# In-Memory Article Filtering Instead of SwiftData Predicate

## Problem Statement

`ArticleListPane` fetches ALL articles from SwiftData via `@Query`, then filters them in-memory using a computed property. This creates O(n) filtering on every view body evaluation instead of O(log n) database-level filtering.

## Findings

**Location:** `Luego/Features/ReadingList/Views/ArticleListPane.swift:8,13-15`

**Current Code:**
```swift
@Query(sort: \Article.savedDate, order: .reverse) private var allArticles: [Article]

private var filteredArticles: [Article] {
    filter.filtered(allArticles)  // O(n) in-memory scan
}
```

**Performance Impact (projected):**
| Articles | Current (in-memory) | With Predicate (DB) |
|----------|---------------------|---------------------|
| 100      | ~1ms               | ~0.3ms             |
| 1,000    | ~10ms              | ~1ms               |
| 10,000   | ~100ms (UI jank)   | ~5ms               |

## Proposed Solutions

### Option A: Dynamic @Query with predicate (Recommended)
**Pros:** O(log n) with indexes, proper SwiftData usage
**Cons:** Requires restructuring init
**Effort:** Medium
**Risk:** Low

```swift
init(filter: ArticleFilter, selectedArticle: Binding<Article?>) {
    self.filter = filter
    self._selectedArticle = selectedArticle

    let predicate: Predicate<Article>
    switch filter {
    case .readingList:
        predicate = #Predicate { !$0.isFavorite && !$0.isArchived }
    case .favorites:
        predicate = #Predicate { $0.isFavorite }
    case .archived:
        predicate = #Predicate { $0.isArchived }
    case .discovery:
        predicate = #Predicate { _ in false }
    }

    _allArticles = Query(filter: predicate, sort: \.savedDate, order: .reverse)
}
```

### Option B: Keep current approach for now
**Pros:** Simpler, works for small datasets
**Cons:** Performance degrades at scale
**Effort:** None
**Risk:** Technical debt

## Recommended Action

Option B for now (acceptable for MVP), but create follow-up ticket for Option A before user base grows.

## Technical Details

**Affected files:**
- `Luego/Features/ReadingList/Views/ArticleListPane.swift`

**Note:** The existing iPhone flow in `ArticleListView.swift` has the same pattern and should be updated together.

## Acceptance Criteria

- [ ] Articles filtered at database level using SwiftData predicates
- [ ] Performance validated with 1000+ test articles
- [ ] No regression in filtering behavior

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Identified in performance review | @Query should use predicates for large datasets |

## Resources

- [SwiftData Predicate Documentation](https://developer.apple.com/documentation/swiftdata/predicate)
- Branch: esoxjem/ipad-3-pane-view
