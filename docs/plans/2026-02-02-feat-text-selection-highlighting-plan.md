---
title: "feat: Add text selection and highlighting to Reader"
type: feat
date: 2026-02-02
revised: 2026-02-02
---

# feat: Add Text Selection and Highlighting to Reader

## Overview

Replace MarkdownUI with native UITextView (iOS) / NSTextView (macOS) to enable text selection and persistent highlights in the Reader view.

## Problem Statement

MarkdownUI renders markdown as SwiftUI `View` hierarchies. SwiftUI's `Text` is a drawing primitive—it doesn't support text selection or highlighting.

**User need**: Select text to copy quotes, highlight important passages.

## Proposed Solution

### Architecture

```
ReaderView
    └── SelectableTextView (UIViewRepresentable / NSViewRepresentable)
            └── UITextView (iOS) / NSTextView (macOS)
                    - NSAttributedString from markdown
                    - Delegate for selection changes
                    - Highlights as background color attributes

ReaderViewModel
    └── Highlight CRUD (inline, no separate service)
            └── Highlight (@Model with Article relationship)
```

### Data Flow

1. Article opens → Convert markdown to `NSAttributedString` → Fetch highlights → Apply background colors → Render
2. User selects text → Delegate callback → Show highlight menu
3. User picks color → Create `Highlight` → Save → Re-render

## Technical Approach

### Phase 1: Text Selection (Ship First, Validate Core Change)

Get text selection working before adding persistence complexity.

#### 1.1 Create SelectableTextView (Single File, Both Platforms)

**File**: `Luego/Core/UI/Readers/SelectableTextView.swift`

```swift
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct SelectableTextView: View {
    let markdown: String
    let highlights: [Highlight]
    var onSelectionChange: ((NSRange) -> Void)?

    var body: some View {
        SelectableTextViewRepresentable(
            markdown: markdown,
            highlights: highlights,
            onSelectionChange: onSelectionChange
        )
    }
}

// MARK: - iOS

#if os(iOS)
struct SelectableTextViewRepresentable: UIViewRepresentable {
    let markdown: String
    let highlights: [Highlight]
    var onSelectionChange: ((NSRange) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if content actually changed (avoid losing selection)
        let newHash = markdown.hashValue ^ highlights.hashValue
        guard newHash != context.coordinator.lastContentHash else { return }

        let currentSelection = textView.selectedRange
        textView.attributedText = buildAttributedString(markdown: markdown, highlights: highlights)

        // Restore selection if still valid
        if currentSelection.location + currentSelection.length <= textView.attributedText.length {
            textView.selectedRange = currentSelection
        }

        context.coordinator.lastContentHash = newHash
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingCompressedSize.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextViewRepresentable
        var lastContentHash: Int = 0

        init(_ parent: SelectableTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // No async dispatch - delegate is already on main thread
            parent.onSelectionChange?(textView.selectedRange)
        }
    }
}

// MARK: - macOS

#else
struct SelectableTextViewRepresentable: NSViewRepresentable {
    let markdown: String
    let highlights: [Highlight]
    var onSelectionChange: ((NSRange) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 24, height: 16)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let newHash = markdown.hashValue ^ highlights.hashValue
        guard newHash != context.coordinator.lastContentHash else { return }

        let currentSelection = textView.selectedRange()
        textView.textStorage?.setAttributedString(buildAttributedString(markdown: markdown, highlights: highlights))

        // Restore selection if still valid
        if let length = textView.textStorage?.length,
           currentSelection.location + currentSelection.length <= length {
            textView.setSelectedRange(currentSelection)
        }

        context.coordinator.lastContentHash = newHash
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SelectableTextViewRepresentable
        var lastContentHash: Int = 0

        init(_ parent: SelectableTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onSelectionChange?(textView.selectedRange())
        }
    }
}
#endif

// MARK: - Markdown Conversion (shared)

private func buildAttributedString(markdown: String, highlights: [Highlight]) -> NSAttributedString {
    let result: NSMutableAttributedString

    if let parsed = try? AttributedString(markdown: markdown, options: .init(
        interpretedSyntax: .full,
        failurePolicy: .returnPartiallyParsedIfPossible
    )) {
        result = NSMutableAttributedString(parsed)
    } else {
        result = NSMutableAttributedString(string: markdown)
    }

    // Apply reader theme
    let fullRange = NSRange(location: 0, length: result.length)

    #if os(iOS)
    let font = UIFont(name: "Georgia", size: 18) ?? UIFont.systemFont(ofSize: 18)
    #else
    let font = NSFont(name: "Georgia", size: 18) ?? NSFont.systemFont(ofSize: 18)
    #endif

    result.addAttribute(.font, value: font, range: fullRange)

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 6
    result.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

    // Apply highlights (using UTF-16 safe conversion)
    let nsString = result.string as NSString
    for highlight in highlights {
        if let range = resolveHighlightRange(highlight, in: result.string, nsString: nsString) {
            #if os(iOS)
            let color = UIColor.systemYellow.withAlphaComponent(0.4)
            #else
            let color = NSColor.systemYellow.withAlphaComponent(0.4)
            #endif
            result.addAttribute(.backgroundColor, value: highlightColor(highlight.color), range: range)
        }
    }

    return result
}

private func resolveHighlightRange(_ highlight: Highlight, in content: String, nsString: NSString) -> NSRange? {
    // CRITICAL: NSRange uses UTF-16 offsets, not character counts
    // Phase 1: Try exact position match using UTF-16 safe access
    guard highlight.startOffset >= 0,
          highlight.endOffset <= nsString.length else {
        return tryFuzzyMatch(highlight, in: content)
    }

    let proposedRange = NSRange(location: highlight.startOffset, length: highlight.endOffset - highlight.startOffset)
    let substring = nsString.substring(with: proposedRange)

    if substring == highlight.text {
        return proposedRange
    }

    // Phase 2: Fuzzy search
    return tryFuzzyMatch(highlight, in: content)
}

private func tryFuzzyMatch(_ highlight: Highlight, in content: String) -> NSRange? {
    if let range = content.range(of: highlight.text) {
        return NSRange(range, in: content)
    }
    return nil
}

private func highlightColor(_ color: HighlightColor) -> Any {
    #if os(iOS)
    switch color {
    case .yellow: return UIColor.systemYellow.withAlphaComponent(0.4)
    case .green: return UIColor.systemGreen.withAlphaComponent(0.4)
    case .blue: return UIColor.systemBlue.withAlphaComponent(0.4)
    case .pink: return UIColor.systemPink.withAlphaComponent(0.4)
    }
    #else
    switch color {
    case .yellow: return NSColor.systemYellow.withAlphaComponent(0.4)
    case .green: return NSColor.systemGreen.withAlphaComponent(0.4)
    case .blue: return NSColor.systemBlue.withAlphaComponent(0.4)
    case .pink: return NSColor.systemPink.withAlphaComponent(0.4)
    }
    #endif
}
```

### Phase 2: Highlighting

#### 2.1 Create Highlight Model (with Article Relationship)

**File**: `Luego/Core/Models/Highlight.swift`

```swift
import Foundation
import SwiftData

enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink
}

@Model
final class Highlight {
    var id: UUID = UUID()

    // UTF-16 offsets (matches NSRange)
    var startOffset: Int = 0
    var endOffset: Int = 0

    // The highlighted text (for fuzzy recovery if offsets fail)
    var text: String = ""

    var color: HighlightColor = .yellow
    var createdAt: Date = Date()

    // Relationship to Article (enables cascade delete)
    var article: Article?

    init(range: NSRange, text: String, color: HighlightColor = .yellow) {
        self.id = UUID()
        self.startOffset = range.location
        self.endOffset = range.location + range.length
        self.text = text
        self.color = color
        self.createdAt = Date()
    }
}
```

#### 2.2 Update Article Model

**File**: `Luego/Core/Models/Article.swift` (add relationship)

```swift
// Add to Article class:
@Relationship(deleteRule: .cascade, inverse: \Highlight.article)
var highlights: [Highlight] = []
```

#### 2.3 Update Schema

**File**: `Luego/App/LuegoApp.swift`

```swift
let schema = Schema([
    Article.self,
    Highlight.self,
])
```

#### 2.4 Highlight Menu View

**File**: `Luego/Features/Reader/Views/HighlightMenuView.swift`

```swift
import SwiftUI

struct HighlightMenuView: View {
    let onColorSelected: (HighlightColor) -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    onColorSelected(color)
                } label: {
                    Circle()
                        .fill(swiftUIColor(for: color))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Highlight \(color.rawValue)")
            }

            if let onDelete {
                Divider().frame(height: 24)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete highlight")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func swiftUIColor(for color: HighlightColor) -> Color {
        switch color {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        }
    }
}
```

#### 2.5 Update ReaderViewModel (Inline Highlight CRUD)

**File**: `Luego/Features/Reader/ViewModels/ReaderViewModel.swift` (additions)

```swift
// Properties
var selectedRange: NSRange = NSRange(location: 0, length: 0)
var selectedHighlight: Highlight?
var showHighlightMenu: Bool { selectedRange.length > 0 || selectedHighlight != nil }
var highlightError: String?

// Computed (highlights come from Article relationship)
var highlights: [Highlight] { article.highlights }

// Methods
func createHighlight(color: HighlightColor) {
    guard selectedRange.length > 0,
          let content = article.content else { return }

    // Extract selected text using UTF-16 safe access
    let nsString = content as NSString
    guard selectedRange.location + selectedRange.length <= nsString.length else { return }
    let selectedText = nsString.substring(with: selectedRange)

    let highlight = Highlight(range: selectedRange, text: selectedText, color: color)
    highlight.article = article
    article.highlights.append(highlight)

    do {
        try modelContext.save()
        selectedRange = NSRange(location: 0, length: 0)
    } catch {
        highlightError = "Could not save highlight"
    }
}

func deleteHighlight(_ highlight: Highlight) {
    article.highlights.removeAll { $0.id == highlight.id }
    modelContext.delete(highlight)

    do {
        try modelContext.save()
        selectedHighlight = nil
    } catch {
        highlightError = "Could not delete highlight"
    }
}
```

#### 2.6 Update ReaderView

**File**: `Luego/Features/Reader/Views/ReaderView.swift`

Replace `Markdown()` usage:

```swift
// BEFORE
Markdown(stripFirstH1FromMarkdown(content, matchingTitle: article.title))
    .markdownTheme(.reader)
    .markdownImageProvider(ReaderImageProvider())

// AFTER
SelectableTextView(
    markdown: stripFirstH1FromMarkdown(content, matchingTitle: article.title),
    highlights: viewModel.highlights,
    onSelectionChange: { range in
        viewModel.selectedRange = range
    }
)
.overlay(alignment: .top) {
    if viewModel.showHighlightMenu {
        HighlightMenuView(
            onColorSelected: { color in
                viewModel.createHighlight(color: color)
            },
            onDelete: viewModel.selectedHighlight != nil ? {
                if let highlight = viewModel.selectedHighlight {
                    viewModel.deleteHighlight(highlight)
                }
            } : nil
        )
        .transition(.opacity.combined(with: .scale))
    }
}
```

## Acceptance Criteria

- [ ] Text can be selected and copied in Reader view (iOS and macOS)
- [ ] Users can highlight selected text with 4 color choices
- [ ] Highlights persist across app launches
- [ ] Highlights sync via CloudKit
- [ ] Deleting an article deletes its highlights (cascade)
- [ ] Users can delete highlights
- [ ] No crashes with emoji/Unicode text (UTF-16 handled correctly)

## Files to Create

| File | Purpose |
|------|---------|
| `Luego/Core/UI/Readers/SelectableTextView.swift` | Text view with both platforms |
| `Luego/Core/Models/Highlight.swift` | SwiftData model + enum |
| `Luego/Features/Reader/Views/HighlightMenuView.swift` | Color picker |
| `LuegoTests/Core/Models/HighlightTests.swift` | Model + UTF-16 tests |

## Files to Modify

| File | Change |
|------|--------|
| `Luego/Core/Models/Article.swift` | Add highlights relationship |
| `Luego/App/LuegoApp.swift` | Add Highlight to schema |
| `Luego/Features/Reader/Views/ReaderView.swift` | Replace Markdown() |
| `Luego/Features/Reader/ViewModels/ReaderViewModel.swift` | Add highlight methods |

## Out of Scope (MVP)

- Discovery view highlighting (Reader only)
- Highlight notes
- Highlights list view
- Fuzzy anchoring with prefix/suffix (text field sufficient for fallback)

## Testing Requirements

- [ ] Test highlight creation with emoji text ("Hello 👋 world")
- [ ] Test highlight persistence after app restart
- [ ] Test cascade delete (delete article → highlights gone)
- [ ] Test on both iOS Simulator and macOS
- [ ] Test selection across formatted text (bold + italic spanning)

## References

- Brainstorm: `docs/brainstorms/2026-02-02-replace-markdownui-uikit-brainstorm.md`
- GIFImageView pattern: `Luego/Core/UI/GIFImageView.swift`
- [Chris Eidhof - UIViewRepresentable](https://chris.eidhof.nl/post/view-representable/)

## Reviewer Feedback Incorporated

| Issue | Resolution |
|-------|------------|
| UTF-16 vs character index mismatch (Kieran) | Use `NSString` for UTF-16 safe substring access |
| Missing Article-Highlight relationship (Kieran) | Added `@Relationship` with cascade delete |
| Race condition in selection (Kieran) | Removed `DispatchQueue.main.async` |
| updateUIView always re-renders (Kieran) | Track content hash, only update when changed |
| HighlightService unnecessary (DHH, Simplicity) | Inlined into ReaderViewModel |
| Too many files (DHH, Simplicity) | Combined into single SelectableTextView.swift |
| YAGNI: prefix/suffix fields (DHH, Simplicity) | Removed, using `text` field for fallback |
| YAGNI: note field (Simplicity) | Removed |
| Raw string colors (Simplicity) | Using `HighlightColor` enum |
| Discovery view scope creep (Simplicity) | Explicitly out of scope |
