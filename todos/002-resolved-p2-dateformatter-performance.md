---
status: resolved
priority: p2
issue_id: "002"
tags: [code-review, performance, dateformatter, swiftui]
dependencies: []
resolution: implemented
---

# DateFormatter Created Repeatedly in Views (Performance Issue)

## Problem Statement

`DateFormatter` instances are created inside computed properties and view bodies, causing expensive object allocation on every render. With large article lists, this causes scroll stuttering and increased memory pressure.

**Why it matters:** Poor scrolling performance degrades user experience, especially on older devices or with large reading lists.

## Findings

### Evidence

**File:** `Luego/Features/ReadingList/Views/ArticleRowView.swift` (lines 85-105)
```swift
private func formatDisplayDate(_ article: Article) -> String {
    // ...
    if calendar.isDateInToday(displayDate) {
        let formatter = DateFormatter()  // NEW on every call
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: displayDate)
    } // ... 2 more formatters created in other branches
}
```

**File:** `Luego/Features/ReadingList/Views/SidebarView.swift` (lines 73-78, 162-167)
```swift
private var formattedTime: String? {
    guard let time = lastSyncTime else { return nil }
    let formatter = DateFormatter()  // NEW on every access
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: time)
}
```

**File:** `Luego/Features/Settings/Views/SettingsView.swift` (lines 205-210)
- Same pattern with DateFormatter in computed property

### Impact Analysis

| Articles | Performance Impact |
|----------|-------------------|
| 100 | Moderate - noticeable during fast scroll |
| 500 | High - scroll stuttering |
| 1000+ | Severe - significant UI lag |

## Proposed Solutions

### Option A: Static Cached Formatters (Recommended)

Create a shared enum with static lazy-initialized formatters.

```swift
private enum DateFormatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    static let weekday: DateFormatter = { ... }()
    static let shortDate: DateFormatter = { ... }()
}
```

**Pros:**
- Zero allocations during scrolling
- Thread-safe (static let)
- Simple refactor

**Cons:**
- Formatters cached for app lifetime
- Must handle locale changes if needed

**Effort:** Small
**Risk:** Low

### Option B: Extension on Date

Add formatting methods directly to Date type.

**Pros:**
- Clean API at call sites
- Encapsulates formatter details

**Cons:**
- Extends Foundation type
- Same caching approach needed internally

**Effort:** Small
**Risk:** Low

## Recommended Action

Implement Option A - create static DateFormatters enum, consolidate all formatting logic.

## Technical Details

**Affected Files:**
- `Luego/Features/ReadingList/Views/ArticleRowView.swift`
- `Luego/Features/ReadingList/Views/SidebarView.swift`
- `Luego/Features/Settings/Views/SettingsView.swift`
- `Luego/Features/Reader/Views/ReaderView.swift`
- `Luego/Features/Discovery/Views/DiscoveryArticleContentView.swift`

**Components:** All views displaying dates

## Acceptance Criteria

- [x] DateFormatter instances are created once and reused
- [x] No new DateFormatter allocation during list scrolling
- [x] Smooth scrolling performance with 500+ articles
- [x] All date displays work correctly

## Work Log

| Date | Action | Learnings |
|------|--------|-----------|
| 2026-01-30 | Created during PR #38 review | Found by performance-oracle agent |
| 2026-01-30 | Implemented Option A: static DateFormatters enum | Created `Luego/Core/Utilities/DateFormatters.swift` with cached formatters |

## Resources

- PR #38: https://github.com/esoxjem/Luego/pull/38
- [Apple: DateFormatter is expensive](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DataFormatting/Articles/dfDateFormatting10_4.html)
