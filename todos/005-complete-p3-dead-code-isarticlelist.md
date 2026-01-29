---
status: pending
priority: p3
issue_id: "005"
tags: [code-review, dead-code, cleanup]
dependencies: []
---

# Dead Code: Unused `isArticleList` Property

## Problem Statement

The `isArticleList` property was added to `ArticleFilter` but is never used in the codebase. It was planned for conditional logic that was implemented differently.

## Findings

**Location:** `Luego/Features/ReadingList/Views/ArticleFilter.swift:28-30`

**Unused Code:**
```swift
var isArticleList: Bool {
    self != .discovery
}
```

**Analysis:**
- Added in this branch as part of the iPad layout work
- Plan document shows it was intended for: `if selectedFilter.isArticleList {...}`
- Actual implementation uses: `if selectedFilter == .discovery {...}` instead
- `grep -r "isArticleList" Luego/` returns only the definition, no usages

## Proposed Solutions

### Option A: Remove the property (Recommended)
**Pros:** Eliminates dead code
**Cons:** None
**Effort:** Small (3 lines)
**Risk:** None

### Option B: Keep for future use
**Pros:** May be useful later
**Cons:** Violates YAGNI, adds confusion
**Effort:** None
**Risk:** Low (technical debt)

## Recommended Action

Option A - remove dead code.

## Technical Details

**Affected files:**
- `Luego/Features/ReadingList/Views/ArticleFilter.swift`

**Lines to remove:**
```swift
var isArticleList: Bool {
    self != .discovery
}
```

## Acceptance Criteria

- [ ] `isArticleList` property removed from `ArticleFilter`
- [ ] Project builds successfully
- [ ] No references to removed property

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Identified in simplicity review | Property added but never used |

## Resources

- Plan document: `docs/plans/2026-01-29-feat-ipad-3-pane-layout-plan.md`
- Branch: esoxjem/ipad-3-pane-view
