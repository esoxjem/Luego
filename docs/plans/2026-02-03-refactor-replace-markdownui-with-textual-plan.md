---
title: "refactor: Replace MarkdownUI with Textual"
type: refactor
date: 2026-02-03
---

# refactor: Replace MarkdownUI with Textual

## Overview

Replace `MarkdownUI` (2.4.1) with its spiritual successor [`Textual`](https://github.com/gonzalezreal/textual) — both by the same author (gonzalezreal). Textual is a general-purpose SwiftUI text rendering engine that uses SwiftUI's native `Text` pipeline for better performance and platform consistency. This migration also eliminates the `NetworkImage` transitive dependency by replacing its one usage with `AsyncImage`.

## Problem Statement

MarkdownUI is no longer the author's actively developed library. Textual is positioned as its replacement with:

- Native SwiftUI `Text` rendering pipeline (better performance)
- Built-in image loading with caching and task deduplication
- Support for animated image formats (GIF, APNG, WebP)
- Cleaner API under `.textual` namespace
- Same `.gitHub` style preset

## Proposed Solution

Swap the SPM dependency and migrate 6 files that reference MarkdownUI. Replace the `NetworkImage` usage in `ArticleRowView` with `AsyncImage`.

## Technical Approach

### Files to Modify (7 total)

| # | File | Changes |
|---|------|---------|
| 1 | `Luego.xcodeproj` | Remove `swift-markdown-ui` SPM dep, add `textual` |
| 2 | `Luego/Features/Reader/Views/ReaderView.swift` | `import Textual`, `StructuredText`, `.textual.structuredTextStyle()`, `.textual.imageAttachmentLoader()` |
| 3 | `Luego/Features/Discovery/Views/DiscoveryArticleContentView.swift` | Same changes as ReaderView |
| 4 | `Luego/Features/Discovery/Views/DiscoveryReaderView.swift` | Change `import MarkdownUI` → `import Textual` (or remove — unused) |
| 5 | `Luego/Core/UI/Readers/ReaderTheme.swift` | `import Textual`, migrate `Theme` extension → `StructuredText.Style` extension |
| 6 | `Luego/Core/UI/Readers/ReaderImageProvider.swift` | Delete file (Textual's built-in `URLAttachmentLoader` replaces it) |
| 7 | `Luego/Features/ReadingList/Views/ArticleRowView.swift` | Replace `import NetworkImage` + `NetworkImage(url:)` → `AsyncImage(url:)` |

### Files to Delete (1)

| File | Reason |
|------|--------|
| `Luego/Core/UI/Readers/ReaderImageProvider.swift` | Textual's built-in `URLAttachmentLoader` provides async image loading with caching |

### Files Unchanged (2)

| File | Reason |
|------|--------|
| `Luego/Core/UI/Readers/MarkdownUtilities.swift` | No MarkdownUI import; operates on raw markdown strings |
| `Luego/Core/UI/Readers/ReaderMarkdownImageView.swift` | May be kept for `ArticleRowView` thumbnail loading, or deleted if `AsyncImage` suffices |

### Dependencies

**Remove:**
- `swift-markdown-ui` (2.4.1) — removes transitive deps: `NetworkImage` (6.0.1), `swift-cmark` (0.7.1)

**Add:**
- `textual` from `https://github.com/gonzalezreal/textual` — has its own `swift-cmark` dependency

### Migration Details

#### 1. SPM Dependency Swap (`Luego.xcodeproj`)

In Xcode:
1. Remove `swift-markdown-ui` package dependency
2. Add `https://github.com/gonzalezreal/textual` package dependency
3. Add `Textual` library to both `Luego` and `LuegoShareExtension` targets (if needed)

#### 2. Reader Content Views (`ReaderView.swift`, `DiscoveryArticleContentView.swift`)

```swift
// Before
import MarkdownUI

Markdown(stripFirstH1FromMarkdown(content, matchingTitle: article.title))
    .markdownTheme(.reader)
    .markdownImageProvider(ReaderImageProvider())

// After
import Textual

StructuredText(markdown: stripFirstH1FromMarkdown(content, matchingTitle: article.title))
    .textual.structuredTextStyle(.reader)
    .textual.imageAttachmentLoader(.image())
```

#### 3. Theme (`ReaderTheme.swift`)

```swift
// Before
import MarkdownUI

extension Theme {
    static let reader = Theme.gitHub
        .text {
            FontSize(18)
        }
}

// After
import Textual

extension StructuredText.Style where Self == ReaderStructuredTextStyle {
    static var reader: ReaderStructuredTextStyle { ReaderStructuredTextStyle() }
}

struct ReaderStructuredTextStyle: StructuredText.Style {
    // Extend .gitHub with font scale adjustment
    // Use .textual.fontScale() or paragraph style override for 18pt body text
}
```

> **Note:** The exact API for font size override within a `StructuredText.Style` needs verification. Textual uses `.textual.fontScale()` modifier or custom paragraph styles. The `.gitHub` base style is confirmed available.

The `Color.gitHubBackground` extension is pure SwiftUI and stays unchanged — just remove the `import MarkdownUI` from the file.

#### 4. Image Provider → Built-in AttachmentLoader

Delete `ReaderImageProvider.swift`. Textual's built-in `URLAttachmentLoader` (via `.image()`) provides:
- Async URL-based image loading
- Built-in caching via `ImageLoader.shared` with `returnCacheDataElseLoad` policy
- Task deduplication for concurrent requests
- Placeholder during loading
- Support for animated formats (GIF, APNG, WebP)

The custom `ReaderMarkdownImageView.swift` with manual `NSCache` is no longer needed for markdown rendering. Evaluate whether to keep it for other uses or delete.

#### 5. ArticleRowView Thumbnail (`ArticleRowView.swift`)

```swift
// Before
import NetworkImage

NetworkImage(url: url) { state in
    switch state {
    case .empty:
        placeholderView
    case .success(let image, _):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failure:
        placeholderView
    }
}

// After
AsyncImage(url: url) { phase in
    switch phase {
    case .empty:
        placeholderView
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    case .failure:
        placeholderView
    @unknown default:
        placeholderView
    }
}
```

#### 6. DiscoveryReaderView.swift

Change `import MarkdownUI` to `import Textual` (or remove entirely — no MarkdownUI types are used directly in this file).

## Acceptance Criteria

- [x] MarkdownUI removed from SPM dependencies
- [x] Textual added as SPM dependency
- [x] `NetworkImage` no longer in dependency graph
- [x] All 6 files with `import MarkdownUI` compile with `import Textual` (or import removed)
- [x] `ArticleRowView` thumbnails render correctly with `AsyncImage`
- [x] Reader view renders article markdown with `.gitHub`-based theme
- [x] Body text renders at ~18pt size (matching current reader experience)
- [x] Images in markdown articles load and display correctly
- [x] Dark mode background color (`gitHubBackground`) unchanged
- [x] H1 stripping still works (no MarkdownUI dependency in `MarkdownUtilities.swift`)
- [x] Code blocks render in monospace (not affected by parent `.fontDesign(.serif)`)
- [x] Discovery reader renders identically to main reader
- [x] App builds for both iOS and macOS targets
- [x] All existing tests pass
- [x] `agent_docs/reader.md` updated to reference Textual instead of MarkdownUI

## Known Risks & Mitigations

### Read Position Drift (Low Impact)

Existing saved read positions (stored as 0.0-1.0 ratio) may map to slightly different absolute positions because Textual may render with different spacing/sizing. This is acceptable — positions will be approximate. No migration logic needed.

### Font Design Inheritance (Medium, Verify Empirically)

Both reader views apply `.fontDesign(.serif)` on the parent VStack. MarkdownUI's `Markdown` view may have ignored this environment value, but Textual's `StructuredText` (built on native SwiftUI `Text`) may inherit it. If code blocks render in serif, move `.fontDesign(.serif)` to the `ArticleHeaderView` only instead of the parent VStack.

### Inline HTML in Articles (Low Impact)

Some fetched articles may contain inline HTML within markdown (e.g., `<br>`, `<sup>`). Neither MarkdownUI nor Textual fully supports inline HTML. The content pipeline (`LuegoSDK` / `MetadataDataSource`) converts HTML to markdown, so most HTML should already be converted before reaching the renderer.

### Theme Parity (Verify Visually)

While both libraries offer a `.gitHub` style by the same author, minor visual differences in heading sizes, link colors, list indentation, or blockquote styling are possible. Compare side-by-side with a representative article.

## Implementation Order

1. **Swap SPM dependency** — Remove MarkdownUI, add Textual in Xcode
2. **Fix compilation errors** — Update imports and API calls in all 6 files
3. **Migrate theme** — Create `StructuredText.Style` extension for `.reader`
4. **Replace NetworkImage** — Change `ArticleRowView` to use `AsyncImage`
5. **Delete ReaderImageProvider.swift** — Remove now-unnecessary file
6. **Evaluate ReaderMarkdownImageView.swift** — Delete if no longer referenced
7. **Test visually** — Render articles in both Reader and Discovery
8. **Verify font/code blocks** — Check `.fontDesign(.serif)` inheritance
9. **Update agent docs** — Reflect new library in `agent_docs/reader.md`
10. **Run full test suite** — Ensure no regressions

## References

### Internal
- `Luego/Core/UI/Readers/ReaderTheme.swift:11-16` — Current theme definition
- `Luego/Core/UI/Readers/ReaderImageProvider.swift:1-8` — Current ImageProvider
- `Luego/Features/Reader/Views/ReaderView.swift:83-85` — Main markdown rendering
- `Luego/Features/Discovery/Views/DiscoveryArticleContentView.swift:19-21` — Discovery markdown rendering
- `Luego/Features/ReadingList/Views/ArticleRowView.swift:190` — NetworkImage usage
- `agent_docs/reader.md` — Reader feature documentation

### External
- Textual repository: https://github.com/gonzalezreal/textual
- MarkdownUI repository: https://github.com/gonzalezreal/swift-markdown-ui
