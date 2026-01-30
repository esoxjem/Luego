---
date: 2026-01-30
topic: macos-visual-redesign
---

# macOS Visual Redesign - Native Polish

## What We're Building

A visual refresh of Luego's macOS interface to achieve a polished, native macOS aesthetic inspired by NetNewsWire. The goal is **balanced density** with comfortable reading, not maximum information cramming.

Key improvements:
- **Refined sidebar** with proper vibrancy, typography, and spacing
- **Medium-density article rows** with thumbnails, titles, excerpts, and subtle metadata
- **NetNewsWire-style toolbar** - minimal and clean
- **Pastel color palette** that feels warm and inviting (matching "Luego" branding)

## Why This Approach

We chose **Native Polish Refinement** over a full redesign because:

1. **Builds on working code** - The three-column NavigationSplitView structure is already correct
2. **Lower risk** - Incremental improvements are easier to validate
3. **Maintains iOS consistency** - Won't diverge too far from the mobile experience
4. **Faster delivery** - Focus on visual refinements rather than structural changes

Alternatives considered:
- **Full NetNewsWire clone** - Too much work, risks over-engineering
- **Design system first** - Good for long-term but overkill for current scope

## Key Decisions

### Sidebar
- **Visual polish only** - Keep current structure (Library + Discover sections)
- **No unread counts** - Keep it simple
- **No folder hierarchy** - Not needed for current use case
- **Refined typography** - Better font sizes, weights, and spacing
- **Settings gear at bottom** - Keep existing pattern

### Article List (Middle Column)
- **Medium-density rows** - Not as dense as NetNewsWire, not as sparse as current
- **Add 1-2 line excerpts** - Show article preview text under title
- **Keep thumbnails** - But refine size and corner radius
- **Subtle metadata** - Date and reading time in tertiary style
- **Better selection states** - Proper accent color highlighting

### Toolbar
- **NetNewsWire-inspired** - Minimal, essential actions only
- **Clean iconography** - Consistent icon weights
- **Remove redundancy** - Settings accessible via sidebar, not toolbar

### Color Palette
- **Pastel tones** - Warm, inviting colors matching "Luego" (later) branding
- **System accent integration** - Respect user's macOS accent color for selection
- **Muted backgrounds** - Don't compete with article content

### Empty State
- **Keep minimal** - Current ContentUnavailableView is fine
- **No illustrations** - Simple and clean

## Visual Reference

**NetNewsWire patterns to adopt:**
- Sidebar vibrancy and section header styling
- Compact toolbar with essential actions
- Clean list selection highlighting
- Proper use of system colors

**Luego patterns to preserve:**
- Serif typography for article titles
- Thumbnail-forward article display
- Read progress indicator
- Three-column layout structure

## Open Questions

- Exact pastel color values to use (coral/peach tones? sage green?)
- Whether to show favicons for article sources
- Hover states for article rows (subtle background change?)

## Files Likely to Change

1. `Features/ReadingList/Views/SidebarView.swift` - Sidebar refinements
2. `Features/ReadingList/Views/ArticleRowView.swift` - Row redesign with excerpts
3. `Features/ReadingList/Views/ArticleListPane.swift` - List styling
4. `App/ContentView.swift` - Toolbar adjustments
5. `Core/UI/` - Possibly new color definitions

## Next Steps

→ `/workflows:plan` for implementation details
→ `/frontend-design` for actual implementation with design iteration
