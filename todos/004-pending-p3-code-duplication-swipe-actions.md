---
status: pending
priority: p3
issue_id: "004"
tags: [code-review, duplication, refactoring]
dependencies: []
---

# Code Duplication: Swipe Action Buttons

## Problem Statement

The swipe action implementations (`favoriteButton`, `archiveButton`, `deleteButton`) are nearly identical between `SelectableArticleList` (iPad) and `ArticleList` (iPhone), resulting in ~40 duplicated lines.

## Findings

**Locations:**
- `Luego/Features/ReadingList/Views/ArticleListPane.swift:96-134` (iPad)
- `Luego/Features/ReadingList/Views/ArticleListView.swift:172-210` (iPhone)

**Duplicate Code Example:**
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
```

**Also duplicated:**
- `archiveButton(for:)` - 15 lines each
- `deleteButton(for:)` - 10 lines each

## Proposed Solutions

### Option A: Extract ViewModifier
**Pros:** Reusable, clean API
**Cons:** ViewModifiers can be complex for beginners
**Effort:** Medium
**Risk:** Low

```swift
struct ArticleSwipeActions: ViewModifier {
    let article: Article
    let viewModel: ArticleListViewModel
    let filter: ArticleFilter
    @Binding var selection: Article?

    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                FavoriteButton(article: article, viewModel: viewModel, filter: filter)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                ArchiveButton(article: article, viewModel: viewModel, filter: filter)
                DeleteButton(article: article, viewModel: viewModel, selection: $selection)
            }
    }
}
```

### Option B: Shared extension on View
**Pros:** Simple to apply
**Cons:** Less encapsulated
**Effort:** Small
**Risk:** Low

### Option C: Leave as-is
**Pros:** No refactoring effort
**Cons:** Maintenance burden, divergence risk
**Effort:** None
**Risk:** Low (technical debt)

## Recommended Action

Option C for MVP (the duplication is isolated and not critical), Option A for future refactoring sprint.

## Technical Details

**Affected files:**
- `Luego/Features/ReadingList/Views/ArticleListPane.swift`
- `Luego/Features/ReadingList/Views/ArticleListView.swift`

**Potential new file:**
- `Luego/Features/ReadingList/Views/ArticleSwipeActions.swift`

## Acceptance Criteria

- [ ] Single source of truth for swipe action logic
- [ ] Both iPad and iPhone lists use shared component
- [ ] No change in user-facing behavior

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Identified in pattern review | Swipe actions are duplicated between layouts |

## Resources

- Branch: esoxjem/ipad-3-pane-view
