---
status: complete
priority: p2
issue_id: 003
tags: [code-review, performance, architecture, swiftui]
dependencies: []
---

# Root ContentView Observes All Articles

# Problem Statement

`ContentView` now observes the full article collection solely to supply `existingArticles` to the macOS add-article sheet. That broadens app-shell invalidation scope and couples the root container to feature-level data churn.

# Findings

- `Luego/App/ContentView.swift:14` introduces `@Query(sort: \Article.savedDate, order: .reverse) private var allArticles: [Article]` at the root view level.
- `Luego/App/ContentView.swift:58-61` only uses that query when the macOS add-article sheet is presented.
- `Luego/Features/ReadingList/Views/ArticleListPane.swift:11,75-77` already scopes the same query closer to the add-article sheet on non-macOS flows.
- `ContentView` also owns macOS split layout state, hover state, and drag state, so every article mutation now has a larger surface area to invalidate.

# Proposed Solutions

## Option 1: Move the query back down to the sheet or a dedicated macOS add-article host

### Pros
- Restores narrow observation scope.
- Keeps feature-specific data closer to the feature UI.

### Cons
- Requires a small wrapper view or sheet host.

### Effort
Small

### Risk
Low

## Option 2: Remove `existingArticles` from the sheet boundary and let the view model/service handle duplicate detection

### Pros
- Stronger architecture boundary.
- Avoids passing full collections through the app shell.

### Cons
- Slightly larger refactor.

### Effort
Medium

### Risk
Low

## Option 3: Cache the required article identity data in a narrower observable model

### Pros
- Keeps the current UI shape.
- Can reduce full-view invalidation.

### Cons
- Adds new state plumbing.
- More complex than moving the query.

### Effort
Medium

### Risk
Medium

# Recommended Action

Move the article query out of `ContentView` and into a narrower macOS sheet host or feature-level boundary so the app shell stops observing the full article collection for this flow.


# Technical Details

- Affected files:
  - `Luego/App/ContentView.swift`
  - `Luego/Features/ReadingList/Views/ArticleListPane.swift`
- Main regression risk:
  - unnecessary `ContentView` body invalidation during article sync/save/delete activity on macOS

# Acceptance Criteria

- [x] `ContentView` no longer observes the entire article collection just to support the add-article sheet.
- [x] Add-article duplicate detection still works on macOS.
- [x] macOS shell layout state remains isolated from routine article mutations.

# Work Log

- 2026-03-14: Code review found a new root-level `@Query` in `ContentView` that is only needed for sheet presentation and widens invalidation scope.

### 2026-03-14 - Approved for Work

**By:** Claude Triage System

**Actions:**
- Issue approved during triage session.
- Status changed from pending to ready.
- Ready to be picked up and worked on.

**Learnings:**
- Root-level observation is broader than needed for a sheet-only dependency.
- Narrowing the query boundary should reduce unnecessary shell invalidation on macOS.

### 2026-03-14 - Resolved

**By:** Droid

**Actions:**
- Removed the root-level `@Query` from `ContentView`.
- Added a macOS-only sheet wrapper that owns the article query at the sheet boundary.
- Verified with `scripts/xcodebuildmcp-luego macos build` and `scripts/xcodebuildmcp-luego simulator build --iphone`.

**Learnings:**
- A narrow wrapper view preserves behavior while avoiding app-shell observation of the full article collection.

# Notes

Source: Triage session on 2026-03-14

# Resources

- Review target: current working tree on `main`
- `Luego/App/ContentView.swift:14,58-61`
- `Luego/Features/ReadingList/Views/ArticleListPane.swift:11,75-77`
