---
title: iPad Inspire Me Button Non-Functional
category: ui-bugs
tags:
  - ipad
  - discovery
  - callback-wiring
  - empty-closure
  - accessibility
module: ReadingList, Discovery
severity: medium
platform: iPad
status: resolved
date_resolved: 2026-01-29
symptoms:
  - Inspire Me button on iPad does nothing when tapped
  - Button visible in empty state and toolbar but non-functional
  - Same button works correctly on iPhone
---

# iPad "Inspire Me" Button Non-Functional

## Problem

The "Inspire Me" button on iPad was a no-op—it displayed correctly but did nothing when tapped. This affected:
- The empty state view when the reading list had no articles
- The toolbar button in the article list pane

The same button worked correctly on iPhone, where it opened a full-screen Discovery modal.

## Root Cause

Two issues combined to cause this bug:

1. **Empty closure placeholder**: `ArticleListPane` was hardcoding `onDiscover: {}` when calling `ArticleListEmptyState`, meaning the callback never did anything.

2. **Missing toolbar button**: The iPad version had no toolbar button for discovery (only iPhone's `ArticleListView` had one).

3. **Different navigation paradigms**: iPad uses sidebar-based state switching (`selectedFilter = .discovery`), while iPhone uses modal presentation (`.fullScreenCover`). The iPad callback was never wired.

**Location**: `Luego/Features/ReadingList/Views/ArticleListPane.swift:22`
```swift
// BEFORE (broken)
ArticleListEmptyState(onDiscover: {}, filter: filter)
```

## Solution

### Step 1: Add callback parameter to ArticleListPane

```swift
struct ArticleListPane: View {
    let filter: ArticleFilter
    @Binding var selectedArticle: Article?
    let onDiscover: () -> Void  // NEW
    // ...
}
```

### Step 2: Wire callback from ContentView

```swift
// In ContentView.swift iPadLayout
ArticleListPane(
    filter: selectedFilter,
    selectedArticle: $selectedArticle,
    onDiscover: { selectedFilter = .discovery }  // NEW
)
```

### Step 3: Pass callback to empty state

```swift
// AFTER (fixed)
ArticleListEmptyState(onDiscover: onDiscover, filter: filter)
```

### Step 4: Add toolbar button matching iPhone

```swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        if filter == .readingList {
            Button(action: onDiscover) {
                Image(systemName: "die.face.5")
            }
            .accessibilityLabel("Inspire Me")
        }
        // ... other buttons
    }
}
```

### Step 5: Add accessibility to iPhone version

```swift
// In ArticleListView.swift
.accessibilityLabel("Inspire Me")
```

## Data Flow

```
User taps "Inspire Me" button
    ↓
ArticleListPane.onDiscover() called
    ↓
ContentView sets selectedFilter = .discovery
    ↓
NavigationSplitView switches to 2-pane Discovery layout
    ↓
DiscoveryPane loads and fetches random article
```

## Files Changed

| File | Change |
|------|--------|
| `Luego/App/ContentView.swift` | Wire `onDiscover` callback |
| `Luego/Features/ReadingList/Views/ArticleListPane.swift` | Add parameter, toolbar button, pass to empty state |
| `Luego/Features/ReadingList/Views/ArticleListView.swift` | Add accessibility label |

## Prevention

### Code Review Checklist

- [ ] Search for empty closures `{}` passed as callback parameters
- [ ] Verify callbacks are wired through the full component hierarchy
- [ ] Test features on both iPhone and iPad simulators
- [ ] Ensure icon-only buttons have accessibility labels

### Patterns to Avoid

```swift
// BAD: Empty closure placeholder
SomeComponent(onAction: {})

// BAD: Unused callback parameter
let onAction: () -> Void  // Never called
```

### Patterns to Prefer

```swift
// GOOD: Always wire callbacks through
SomeComponent(onAction: onAction)

// GOOD: Add accessibility with functionality
Button(action: onAction) {
    Image(systemName: "icon")
}
.accessibilityLabel("Descriptive Label")
```

### Key Lessons

1. **Empty closures compile but silently fail** - They're easy to miss in code review
2. **Platform-specific code paths need equal testing** - iPad and iPhone can have different bugs
3. **Accessibility labels reveal incomplete implementations** - If you can't describe what a button does, it might not do anything
4. **Callback wiring spans multiple files** - Trace the full path from trigger to effect

## Testing

To verify the fix:

1. Run app on iPad simulator
2. Navigate to Reading List (ensure it has articles or is empty)
3. Tap the dice icon in toolbar → should navigate to Discovery
4. If list is empty, tap "Inspire Me" button → should navigate to Discovery
5. Verify VoiceOver announces "Inspire Me" for the button

## Related

- PR #12: fix(ipad): wire up Inspire Me button to Discovery view
- Commit: d58073d
