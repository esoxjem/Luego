# Replace MarkdownUI with UIKit/AppKit Text Views

**Date:** 2026-02-02
**Status:** Ready for planning

## What We're Building

Replace MarkdownUI (SwiftUI-based markdown renderer) with native UITextView (iOS) and NSTextView (macOS) to enable:

1. **Text selection** — Users can select and copy text from articles
2. **Persistent highlights** — Users can highlight passages and save them as annotations
3. **Native text interaction** — Standard iOS/macOS text behaviors (long-press menu, etc.)

### Scope

- **Reader view** — Primary reading experience, needs full text interaction
- **Discovery view** — Also displays article content, should have same capabilities
- **Both platforms** — iOS and macOS must have feature parity

## Why This Approach

### Problem with MarkdownUI

MarkdownUI renders markdown as SwiftUI `View` hierarchies. SwiftUI's `Text` view is a drawing primitive, not a text container — it doesn't support:
- Text selection (no way to select a range)
- Custom text interactions (highlighting, annotations)
- TextKit features (attributed ranges, custom drawing)

### Why UITextView/NSTextView

- **Native text selection** built into TextKit
- **NSAttributedString** supports rich styling and custom attributes for highlights
- **TextKit 2** (iOS 15+/macOS 12+) provides modern APIs for text layout and interaction
- **Apple's markdown parsing** via `AttributedString(markdown:)` handles conversion
- **Similar APIs** on both platforms, minimizing code divergence

### Alternatives Considered

| Approach | Rejected Because |
|----------|------------------|
| WKWebView + JS | Web view overhead, JS bridge complexity, less native feel |
| Hybrid (MarkdownUI + UITextView) | Two rendering systems to maintain, visual inconsistency |
| Third-party library | Most wrap WKWebView or lack annotation support |

## Key Decisions

1. **Use Apple's built-in markdown parsing** via `AttributedString(markdown:)` rather than a third-party parser — well-maintained, good performance

2. **Create SwiftUI wrappers** (`UIViewRepresentable` / `NSViewRepresentable`) to embed native text views in the existing SwiftUI architecture

3. **Reuse existing image handling** — The current `ReaderImageProvider` and caching logic can be adapted for attributed string image attachments

4. **Single rendering path** for both Reader and Discovery views to ensure consistency

5. **Highlights stored in Article model** — Persist highlight ranges alongside article data in SwiftData

## Open Questions

1. **Highlight data model** — How should highlight ranges be stored? (Character ranges may shift if content changes)

2. **Image handling** — NSTextAttachment for images, or overlay approach?

3. **Theme consistency** — How to match current serif font / GitHub-style theme in AttributedString?

4. **Performance** — Need to test with very long articles (10k+ words)

## Current Implementation Reference

### Files to Replace/Modify

```
Luego/Core/UI/Readers/
├── ReaderTheme.swift          # Theme → AttributedString styles
├── ReaderImageProvider.swift  # ImageProvider → NSTextAttachment
├── ReaderMarkdownImageView.swift  # May be adapted or replaced
└── MarkdownUtilities.swift    # stripFirstH1FromMarkdown stays

Luego/Features/Reader/Views/
└── ReaderView.swift           # Markdown() → SelectableTextView

Luego/Features/Discovery/Views/
├── DiscoveryArticleContentView.swift  # Markdown() → SelectableTextView
└── DiscoveryReaderView.swift  # Uses DiscoveryArticleContentView
```

### Current Usage Pattern

```swift
// Current (MarkdownUI)
Markdown(stripFirstH1FromMarkdown(content, matchingTitle: article.title))
    .markdownTheme(.reader)
    .markdownImageProvider(ReaderImageProvider())

// Target (UITextView wrapper)
SelectableMarkdownView(
    content: stripFirstH1FromMarkdown(content, matchingTitle: article.title),
    highlights: article.highlights,
    onHighlight: { range in /* persist */ }
)
```

## Success Criteria

- [ ] Text can be selected and copied in Reader and Discovery views
- [ ] Users can highlight text and highlights persist across app launches
- [ ] Visual appearance matches or improves upon current MarkdownUI styling
- [ ] Works on both iOS and macOS
- [ ] No performance regression with typical articles
- [ ] Images render inline with same caching behavior

## Next Steps

Run `/workflows:plan` to create detailed implementation plan.
