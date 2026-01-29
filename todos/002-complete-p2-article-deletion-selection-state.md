---
status: pending
priority: p2
issue_id: "002"
tags: [code-review, swiftui, state-management]
dependencies: []
---

# Article Deletion Does Not Clear Selection State

## Problem Statement

When an article is deleted via swipe action in `ArticleListPane`, the `selectedArticle` state in `ContentView` still references the deleted article. This can lead to UI inconsistency where the detail pane shows an article that no longer exists in the list.

## Findings

**Location:** `Luego/Features/ReadingList/Views/ArticleListPane.swift:126-133`

**Current Code:**
```swift
private func deleteButton(for article: Article) -> some View {
    Button(role: .destructive) {
        Task {
            await viewModel.deleteArticle(article)
        }
    } label: {
        Label("Delete", systemImage: "trash.fill")
    }
}
```

**Issue:** The `selection: Article?` binding is not cleared when the selected article is deleted.

**From Plan Document (Edge Cases section):**
> - [ ] Deleted article clears selection and shows empty state

This edge case was identified during planning but not implemented.

## Proposed Solutions

### Option A: Clear selection in delete action (Recommended)
**Pros:** Simple, direct fix
**Cons:** None
**Effort:** Small
**Risk:** Low

```swift
private func deleteButton(for article: Article) -> some View {
    Button(role: .destructive) {
        Task {
            if selection?.id == article.id {
                selection = nil
            }
            await viewModel.deleteArticle(article)
        }
    } label: {
        Label("Delete", systemImage: "trash.fill")
    }
}
```

### Option B: Use SwiftData observation
**Pros:** Automatic, handles all deletion scenarios
**Cons:** More complex, may have timing issues
**Effort:** Medium
**Risk:** Medium

## Recommended Action

Option A - straightforward and explicit.

## Technical Details

**Affected files:**
- `Luego/Features/ReadingList/Views/ArticleListPane.swift`

**State flow:**
```
ContentView (@State selectedArticle)
    → ArticleListPane (@Binding selectedArticle)
        → SelectableArticleList (@Binding selection)
            → deleteButton() - needs to clear selection
```

## Acceptance Criteria

- [ ] Deleting the selected article clears the selection
- [ ] Detail pane shows "No Article Selected" placeholder after deletion
- [ ] Deleting a non-selected article doesn't change selection
- [ ] UI doesn't show stale article data after deletion

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Identified in architecture review | SwiftData model references need explicit cleanup |

## Resources

- Plan document: `docs/plans/2026-01-29-feat-ipad-3-pane-layout-plan.md`
- Branch: esoxjem/ipad-3-pane-view
