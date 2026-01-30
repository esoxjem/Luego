# macOS Glass Sidebar Brainstorm

**Date:** 2026-01-30
**Status:** Ready for Planning

## What We're Building

A beautiful glass UI navigation sidebar for macOS that uses native vibrancy effects with full row highlight selection states. The sidebar will feel native to macOS like Finder, Notes, and other system apps.

### Visual Design

```
┌─────────────────────┐
│  📖 Luego (logo)    │  ← App branding
├─────────────────────┤
│  LIBRARY            │  ← Section header
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│▓ Reading List      ▓│  ← Full row highlight (selected)
│▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓│
│    Favorites        │  ← Normal state
│    Archived         │
├─────────────────────┤
│  DISCOVER           │  ← Section header
│    Explore          │
├─────────────────────┤
│                     │
│         ⚙️          │  ← Settings icon pinned to bottom
└─────────────────────┘
```

### Key Visual Elements

1. **Vibrancy Background**: Native macOS `.sidebar` or `.regularMaterial` background
2. **Row Highlight Selection**: Full-width row highlight on selected items (like Finder/Notes) — **NOT glass pill**
3. **Section Dividers**: Visual separation between Library and Discover sections
4. **App Logo**: Luego branding at the top of the sidebar
5. **Bottom Settings**: Settings icon pinned to bottom of sidebar

## Why This Approach

**Native Vibrancy + Row Highlight** was chosen because:

1. **Matches macOS Expectations**: Users expect sidebars to behave like Finder, Notes, Music
2. **Automatic Theming**: Vibrancy adapts to wallpaper and dark/light mode automatically
3. **Native Selection Pattern**: Full row highlight is the standard macOS sidebar behavior
4. **Consistency**: Matches how Apple's own apps handle sidebar selection

### Alternatives Considered (Rejected)

- ~~**Glass Pill Selection**~~: Rejected - feels less native than row highlight
- ~~**Custom Glass Design**~~: Rejected - may feel foreign to macOS users

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Background Style | Native vibrancy (`.sidebar` material) | Feels native, auto-adapts to system |
| Selection State | Full row highlight | Matches Finder/Notes/Music pattern |
| Logo Placement | Top of sidebar | Standard app branding location |
| Section Headers | Uppercase, subtle gray | Matches Finder/Notes pattern |
| Settings Location | Bottom icon | Keeps nav clean, easy access |

## Implementation Considerations

### Platform Conditionals

The sidebar should remain iOS-compatible:
- **macOS**: Full vibrancy with row highlight selection
- **iPad**: Current List-based layout (or enhanced to match)

### Files to Modify

1. `Luego/Features/ReadingList/Views/SidebarView.swift` - Main sidebar implementation
2. `Luego/App/ContentView.swift` - May need sidebar width/style adjustments

### SwiftUI APIs to Use

```swift
// Native vibrancy background
.background(.sidebar)  // or .regularMaterial

// Row highlight selection (using List selection or .listRowBackground)
.listRowBackground(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)

// Or with RoundedRectangle for custom row
.background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6))

// Hover state (macOS)
.onHover { isHovered = $0 }
```

## Open Questions

None - design is fully specified and ready for planning.

## Next Steps

Run `/workflows:plan` to create the implementation plan.
