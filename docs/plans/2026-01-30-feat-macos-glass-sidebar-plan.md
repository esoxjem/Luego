---
title: macOS Glass Sidebar with Native Vibrancy
type: feat
date: 2026-01-30
---

# macOS Glass Sidebar with Native Vibrancy

## Overview

Add native macOS vibrancy and section organization to the sidebar. Uses `List(selection:)` with `.listStyle(.sidebar)` for automatic native row highlighting. iPad behavior remains unchanged.

## Problem Statement

The current `SidebarView` uses manual Button-based selection with custom `listRowBackground` styling. macOS users expect sidebars to have native vibrancy that adapts to wallpaper/dark mode and full-width row highlights like Finder/Notes.

## Proposed Solution

Platform-conditional sidebar: macOS gets native `List(selection:)` with sections, iPad keeps current Button-based layout. Single file change.

### Visual Design

```
┌─────────────────────┐
│  Luego              │  ← Navigation title
├─────────────────────┤
│  LIBRARY            │  ← Section header (auto-uppercased)
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓ Reading List      ▓│  ← Full row highlight (selected)
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│    Favorites        │
│    Archived         │
├─────────────────────┤
│  DISCOVER           │
│    Explore          │
├─────────────────────┤
│         ⚙️          │  ← Settings (opens via SettingsLink)
└─────────────────────┘
```

## Acceptance Criteria

- [x] macOS sidebar has native vibrancy (adapts to wallpaper)
- [x] macOS sidebar shows "Library" and "Discover" section headers
- [x] Selected item shows full-width row highlight
- [x] Settings gear at bottom opens Settings window
- [x] iPad sidebar unchanged (Button-based, no sections)
- [x] Keyboard navigation works on macOS

## Implementation

**File: `Luego/Features/ReadingList/Views/SidebarView.swift`**

```swift
import SwiftUI

struct SidebarView: View {
    @Binding var selection: ArticleFilter

    var body: some View {
        #if os(macOS)
        macOSSidebar
        #else
        iPadSidebar
        #endif
    }

    #if os(macOS)
    private var macOSSidebar: some View {
        List(selection: $selection) {
            Section("Library") {
                filterRow(.readingList)
                filterRow(.favorites)
                filterRow(.archived)
            }
            Section("Discover") {
                filterRow(.discovery)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Luego")
        .safeAreaInset(edge: .bottom) {
            SettingsLink {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.bar)
            .accessibilityLabel("Settings")
        }
    }

    private func filterRow(_ filter: ArticleFilter) -> some View {
        Label(filter.title, systemImage: filter.icon).tag(filter)
    }
    #endif

    private var iPadSidebar: some View {
        List {
            ForEach(ArticleFilter.allCases, id: \.self) { filter in
                Button {
                    selection = filter
                } label: {
                    Label(filter.title, systemImage: filter.icon)
                }
                .listRowBackground(selection == filter ? Color.accentColor.opacity(0.2) : Color.clear)
            }
        }
        .navigationTitle("Luego")
    }
}
```

## Files to Modify

| File | Change |
|------|--------|
| `Luego/Features/ReadingList/Views/SidebarView.swift` | Platform-conditional rewrite |

**No new files. No changes to ArticleFilter.swift.**

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Inline filter arrays | Avoids spreading related code across files |
| Inline settings button | Used once, ~10 lines, doesn't warrant separate file |
| `SettingsLink` over `NSApp.sendAction` | SwiftUI-native, no fragile string selectors |
| Helper function `filterRow(_:)` | DRY without over-abstraction |
| Non-optional selection binding | App always shows one filter view |

## Testing

1. Build for macOS and iOS targets
2. Verify macOS vibrancy adapts to wallpaper
3. Verify macOS row highlight matches Finder
4. Verify iPad sidebar unchanged
5. Test keyboard navigation on macOS

## References

- Current SidebarView: `Luego/Features/ReadingList/Views/SidebarView.swift`
- Platform conditionals pattern: `Luego/Features/Discovery/Views/DiscoveryReaderView.swift:184-188`
- Brainstorm: `docs/brainstorms/2026-01-30-macos-glass-sidebar-brainstorm.md`
