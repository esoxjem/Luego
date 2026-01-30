---
title: "feat: macOS Visual Polish Refinement"
type: feat
date: 2026-01-30
brainstorm: docs/brainstorms/2026-01-30-macos-visual-redesign-brainstorm.md
---

# macOS Visual Polish Refinement

## Overview

A visual refresh of Luego's macOS interface to achieve a polished, native macOS aesthetic inspired by NetNewsWire. This builds on existing macOS support (hover states, three-column layout, Settings scene) with focused refinements to sidebar typography, article row density, and toolbar minimalism.

**Key deliverables:**
- Refined sidebar with section header styling and improved spacing
- Medium-density article rows with 1-2 line excerpts
- Minimal toolbar with essential actions only
- Consistent visual polish across all macOS-specific code

## Problem Statement / Motivation

The current macOS interface works functionally but lacks visual polish:

1. **Sidebar feels generic** - Default SwiftUI section styling doesn't convey the warmth of "Luego" branding
2. **Article rows are too sparse** - No excerpts means users can't scan content quickly
3. **Inconsistent visual hierarchy** - Metadata competes with titles for attention
4. **Toolbar has redundant elements** - Settings button appears when Settings scene exists

The goal is a "balanced density" reading experience - not cramming maximum information, but providing comfortable scanning with enough context to choose what to read.

## Proposed Solution

### Phase 1: Article Excerpt Support

Add excerpt extraction to provide article preview text.

**Approach:** Extract first ~120 characters from article content, stripping markdown, as a computed property. No model changes required.

**Files to modify:**
- `Luego/Core/Models/Article.swift` - Add computed `excerpt` property
- `Luego/Features/ReadingList/Views/ArticleRowView.swift` - Display excerpt below title

### Phase 2: Article Row Refinement

Implement medium-density article rows with improved visual hierarchy.

**Row layout (target ~88px height):**
```
┌─────────────────────────────────────────────────────┐
│ [56x56      ] Title (headline, 2 lines max)         │
│ [thumbnail  ] Excerpt (subheadline, 2 lines)        │
│ [          ] domain • 5 min • Jan 15                │
└─────────────────────────────────────────────────────┘
```

**Changes:**
- Thumbnail: 60x60 → 56x56 (minor adjustment for balance)
- Add excerpt text (2 lines, `.secondary` color)
- Metadata: Move to tertiary visual level (`.caption`, `.tertiary`)
- Spacing: Tighter vertical padding for density

**Files to modify:**
- `Luego/Features/ReadingList/Views/ArticleRowView.swift`

### Phase 3: Sidebar Polish

Refine sidebar section headers and overall typography.

**Changes:**
- Section headers: Custom styling with `.secondary` foreground, letter-spacing
- Row spacing: Slightly tighter vertical rhythm
- Settings gear: Subtle separator line above

**Files to modify:**
- `Luego/Features/ReadingList/Views/SidebarView.swift`

### Phase 4: Toolbar Cleanup

Remove redundancy and ensure minimal, clean toolbar.

**Final toolbar actions:**
- **Add article (+)** - Primary action
- **Inspire Me (die)** - Discovery entry point
- ~~Settings (gear)~~ - Already removed for macOS, verify complete

**Files to modify:**
- `Luego/App/ContentView.swift` (verify)
- `Luego/Features/ReadingList/Views/ArticleListPane.swift` (verify)

## Technical Considerations

### Excerpt Extraction

**Option A: Computed property (recommended)**
```swift
extension Article {
    var excerpt: String {
        guard let content = content else { return "" }
        let stripped = content.strippingMarkdown()
        return String(stripped.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

Pros: No migration, no storage overhead, always fresh
Cons: Computed on every access (minor perf concern for large lists)

**Option B: Stored property**
Pros: Single computation
Cons: Requires model migration, storage overhead

**Decision:** Use computed property. SwiftUI's lazy rendering means excerpts compute only for visible rows.

### Platform Guards

All visual changes use existing `#if os(macOS)` pattern:

```swift
#if os(macOS)
.font(.subheadline)
.foregroundColor(.secondary)
#else
.font(.footnote)
#endif
```

### Accessibility

- Excerpt included in VoiceOver reading order
- Hover states already respect `accessibilityReduceMotion`
- Color contrast ratios must meet WCAG AA (4.5:1 for text)

### Performance

- Excerpt extraction is O(n) on content length - acceptable for typical article lengths
- No new network requests
- No database schema changes

## Acceptance Criteria

### Functional Requirements

- [ ] Article rows display 1-2 line excerpts below titles
- [ ] Excerpts are stripped of markdown formatting
- [ ] Sidebar section headers have refined styling
- [ ] Toolbar shows only Add and Inspire Me buttons on macOS
- [ ] All changes are macOS-only (iOS unchanged)

### Visual Requirements

- [ ] Article row height approximately 88px (current ~72px)
- [ ] Thumbnail size: 56x56 with 8px corner radius
- [ ] Excerpt: 2-line limit with ellipsis truncation
- [ ] Metadata: Caption size, tertiary color
- [ ] Sidebar: Clear section header hierarchy

### Non-Functional Requirements

- [ ] No SwiftData migrations required
- [ ] Article list scrolls smoothly with 100+ articles
- [ ] VoiceOver reads excerpt after title
- [ ] Reduced motion preference respected

## Dependencies & Risks

### Dependencies
- None (builds on existing macOS support)

### Risks

| Risk | Mitigation |
|------|------------|
| Excerpt extraction slow for long articles | Limit extraction to first 500 chars of content before stripping |
| Color choices don't match branding | Use system colors initially; pastel palette deferred to future iteration |
| Typography changes feel jarring | Small, incremental changes; test each phase |

## References & Research

### Internal References
- Recent macOS visual polish: `045c54d` (hover states, toolbar cleanup)
- Existing hover implementation: `Luego/Features/ReadingList/Views/ArticleRowView.swift:28-37`
- Platform guard pattern: `Luego/Features/ReadingList/Views/SidebarView.swift:11-48`
- Color definitions: `Luego/Core/UI/Readers/ReaderTheme.swift:4-9`

### Brainstorm Context
- Brainstorm: `docs/brainstorms/2026-01-30-macos-visual-redesign-brainstorm.md`
- Decisions: Native polish approach, no unread counts, no folder hierarchy
- Deferred: Pastel color palette (no user demand), complex typography overhaul

### External Patterns
- NetNewsWire: Sidebar vibrancy, compact toolbar, clean selection highlighting
- Apple HIG: macOS sidebar conventions, `.listStyle(.sidebar)` defaults

## Open Questions (Deferred)

These items from the brainstorm are intentionally deferred:

1. **Pastel color palette** - Requires design iteration; system colors work well initially
2. **Favicon display** - Nice-to-have; not essential for MVP polish
3. **Unread/read visual distinction** - Common pattern but not in current brainstorm scope
4. **Filter persistence across launches** - UX improvement for separate iteration

## Implementation Checklist

### Phase 1: Excerpt Support
- [ ] Add `excerpt` computed property to Article model extension
- [ ] Add markdown stripping utility if not exists
- [ ] Write unit test for excerpt extraction edge cases

### Phase 2: Article Row
- [ ] Update ArticleRowView with excerpt display (macOS only)
- [ ] Adjust thumbnail size to 56x56
- [ ] Restyle metadata to tertiary visual level
- [ ] Fine-tune vertical spacing for ~88px row height
- [ ] Test with long titles, missing thumbnails, empty content

### Phase 3: Sidebar
- [ ] Style section headers with custom typography
- [ ] Add subtle separator above settings gear
- [ ] Verify vibrancy working correctly with `.sidebar` list style

### Phase 4: Toolbar
- [ ] Verify Settings button hidden on macOS
- [ ] Confirm Add and Inspire Me buttons only
- [ ] Test toolbar appearance in all window sizes

### Validation
- [ ] Test on macOS with VoiceOver
- [ ] Verify iOS builds unchanged
- [ ] Performance test with 200+ articles
- [ ] Screenshot comparison before/after
