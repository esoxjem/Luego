---
status: resolved
priority: p2
issue_id: "007"
tags: [code-review, duplication, simplicity, swiftui]
dependencies: []
resolution: implemented
---

# Duplicate Swipe Action Buttons in ArticleListPane and ArticleListView

## Problem Statement

`favoriteButton(for:)`, `archiveButton(for:)`, and `deleteButton(for:)` functions are copy-pasted nearly verbatim between `SelectableArticleList` (ArticleListPane.swift) and `ArticleList` (ArticleListView.swift).

**Why it matters:** ~40 lines of duplicated code. Changes to swipe action behavior must be made in two places.

## Findings

### Evidence

**File:** `Luego/Features/ReadingList/Views/ArticleListPane.swift` (lines 115-156)
**File:** `Luego/Features/ReadingList/Views/ArticleListView.swift` (lines 191-229)

```swift
// Both files have identical implementations:
private func favoriteButton(for article: Article) -> some View {
    let isFavorited = filter == .favorites
    return Button {
        Task { await viewModel.toggleFavorite(article) }
    } label: {
        Label(
            isFavorited ? "Unfavorite" : "Favorite",
            systemImage: isFavorited ? "heart.slash.fill" : "heart.fill"
        )
    }
    .tint(isFavorited ? .gray : .red)
}

private func archiveButton(for article: Article) -> some View { ... }
private func deleteButton(for article: Article) -> some View { ... }
```

## Proposed Solutions

### Option A: Extract to Shared Extension (Recommended)

Create an extension or helper struct for swipe actions.

```swift
// ArticleSwipeActions.swift
struct ArticleSwipeActions {
    let filter: ArticleFilter
    let viewModel: ArticleListViewModel

    func favoriteButton(for article: Article) -> some View {
        let isFavorited = filter == .favorites
        return Button {
            Task { await viewModel.toggleFavorite(article) }
        } label: {
            Label(
                isFavorited ? "Unfavorite" : "Favorite",
                systemImage: isFavorited ? "heart.slash.fill" : "heart.fill"
            )
        }
        .tint(isFavorited ? .gray : .red)
    }

    // archiveButton, deleteButton...
}
```

**Pros:**
- ~40 LOC saved
- Single source of truth
- Easy to test independently

**Cons:**
- New file/type to maintain

**Effort:** Small
**Risk:** Low

### Option B: ViewModifier Approach

Create a `.articleSwipeActions()` modifier.

**Pros:**
- More SwiftUI-idiomatic

**Cons:**
- Slightly more complex

**Effort:** Medium
**Risk:** Low

## Recommended Action

Implement Option A - extract to shared helper struct.

## Technical Details

**Affected Files:**
- `Luego/Features/ReadingList/Views/ArticleListPane.swift`
- `Luego/Features/ReadingList/Views/ArticleListView.swift`
- New: `Luego/Features/ReadingList/Views/ArticleSwipeActions.swift`

**LOC Reduction:** ~40 lines (net ~35 after new file)

## Acceptance Criteria

- [x] Swipe action logic exists in single location
- [x] Both list views use shared implementation
- [x] All swipe actions work correctly
- [x] No visual changes

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by pattern-recognition and code-simplicity agents |
| 2026-01-30 | Implemented Option A: ArticleSwipeActions struct | Created ArticleSwipeActions.swift with onDelete callback for selection clearing |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
