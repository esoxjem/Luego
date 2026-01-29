---
status: pending
priority: p3
issue_id: "006"
tags: [code-review, naming, consistency]
dependencies: []
---

# Naming Inconsistency: DetailPaneView vs ArticleListPane

## Problem Statement

The new iPad pane views have inconsistent naming: `ArticleListPane` and `DiscoveryPane` use the "Pane" suffix, but `DetailPaneView` uses both "Pane" and "View" suffixes.

## Findings

**Inconsistent naming:**
| View | Suffix | Expected |
|------|--------|----------|
| `ArticleListPane` | Pane | Pane |
| `DiscoveryPane` | Pane | Pane |
| `DetailPaneView` | PaneView | Pane |
| `SidebarView` | View | View (correct - sidebars aren't panes) |

**Location:** `Luego/Features/ReadingList/Views/DetailPaneView.swift`

## Proposed Solutions

### Option A: Rename to DetailPane (Recommended)
**Pros:** Consistent naming
**Cons:** Requires file rename
**Effort:** Small
**Risk:** Low

Rename:
- File: `DetailPaneView.swift` → `DetailPane.swift`
- Struct: `DetailPaneView` → `DetailPane`

### Option B: Keep as-is
**Pros:** No changes needed
**Cons:** Inconsistent naming pattern
**Effort:** None
**Risk:** Low (minor annoyance)

## Recommended Action

Option A - consistency matters for maintainability.

## Technical Details

**Affected files:**
- `Luego/Features/ReadingList/Views/DetailPaneView.swift` (rename file and struct)
- `Luego/App/ContentView.swift` (update reference)

## Acceptance Criteria

- [ ] File renamed to `DetailPane.swift`
- [ ] Struct renamed to `DetailPane`
- [ ] All references updated
- [ ] Project builds successfully

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-29 | Identified in pattern review | Naming consistency across pane views |

## Resources

- Branch: esoxjem/ipad-3-pane-view
