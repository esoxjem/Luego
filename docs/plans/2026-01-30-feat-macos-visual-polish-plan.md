---
title: "feat: macOS Visual Polish - Native Aesthetic Refinements"
type: feat
date: 2026-01-30
source_brainstorm: docs/brainstorms/2026-01-30-macos-visual-redesign-brainstorm.md
---

# macOS Visual Polish - Native Aesthetic Refinements

## Overview

Two targeted fixes to make Luego's macOS interface feel more native:

1. **Remove redundant Settings button** from toolbar (sidebar already has SettingsLink)
2. **Add hover states** on article rows (expected macOS behavior)

Optional enhancement: Add article excerpts for better scannability.

## Problem Statement

- **Redundant UI** - Settings button in toolbar duplicates sidebar gear
- **No hover feedback** - macOS users expect visual response on hover

## Implementation

### 1. Remove Toolbar Settings Button (macOS only)

**File:** `Luego/Features/ReadingList/Views/ArticleListPane.swift`

Wrap the Settings button in a platform guard:

```swift
.toolbar {
    ToolbarItemGroup(placement: .primaryAction) {
        if filter == .readingList {
            Button(action: onDiscover) {
                Image(systemName: "die.face.5")
            }
            .accessibilityLabel("Inspire Me")
        }

        Button { showingAddArticle = true } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add Article")

        #if !os(macOS)
        Button { showingSettings = true } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("Settings")
        #endif
    }
}
```

### 2. Add Hover States (macOS only)

**File:** `Luego/Features/ReadingList/Views/ArticleRowView.swift`

Add hover feedback with proper animation pattern (animation on value change, not state mutation):

```swift
#if os(macOS)
@State private var isHovered = false
@Environment(\.accessibilityReduceMotion) private var reduceMotion
#endif

var body: some View {
    HStack(alignment: .top, spacing: 12) {
        // ... existing content ...
    }
    .padding(.vertical, 4)
    #if os(macOS)
    .background(
        RoundedRectangle(cornerRadius: 6)
            .fill(isHovered ? Color.secondary.opacity(0.08) : Color.clear)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isHovered)
    )
    .onHover { hovering in
        isHovered = hovering
    }
    #endif
}
```

### 3. Article Excerpts (Optional - Can Defer)

If scannability is a priority, add a simple excerpt:

**File:** `Luego/Core/Models/Article.swift` (extension)

```swift
extension Article {
    var excerpt: String? {
        guard let content = content, !content.isEmpty else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 20 else { return nil }

        let truncated = String(trimmed.prefix(120))
        if let lastSpace = truncated.lastIndex(of: " "), truncated.count >= 120 {
            return String(truncated[..<lastSpace]) + "..."
        }
        return truncated.count < trimmed.count ? truncated + "..." : truncated
    }
}
```

**File:** `Luego/Features/ReadingList/Views/ArticleRowView.swift`

Add below the title in `ArticleContentView`:

```swift
if let excerpt = article.excerpt {
    Text(excerpt)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(2)
}
```

## Acceptance Criteria

- [x] Settings button hidden on macOS toolbar, visible on iPad/iPhone
- [x] Hover over article row shows subtle background highlight (macOS only)
- [x] Hover respects `accessibilityReduceMotion` preference
- [x] No regressions on iPad or iPhone

## Files to Modify

| File | Change |
|------|--------|
| `ArticleListPane.swift` | Add `#if !os(macOS)` around Settings button |
| `ArticleRowView.swift` | Add hover state with `.onHover` modifier |
| `Article.swift` | Add `excerpt` computed property (if implementing excerpts) |

## What Was Cut (Per Review Feedback)

Based on DHH, Kieran, and Simplicity reviewer feedback:

- **Pastel color palette** - Premature branding, no user demand
- **Sidebar typography changes** - SwiftUI `.listStyle(.sidebar)` defaults already native
- **Thumbnail size 60→56** - 4px imperceptible, pointless churn
- **Risk matrix** - Overkill for simple changes
- **Complex phasing** - These are independent, small changes

## References

- Brainstorm: `docs/brainstorms/2026-01-30-macos-visual-redesign-brainstorm.md`
- Current row: `Luego/Features/ReadingList/Views/ArticleRowView.swift`
- Institutional learning: Empty closure gotcha from `docs/solutions/ui-bugs/ipad-inspire-me-button-noop.md`
