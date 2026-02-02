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
        textView.dataDetectorTypes = .link
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let newHash = markdown.hashValue ^ highlights.hashValue
        guard newHash != context.coordinator.lastContentHash else { return }

        let currentSelection = textView.selectedRange
        textView.attributedText = buildAttributedString(markdown: markdown, highlights: highlights)

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
            parent.onSelectionChange?(textView.selectedRange)
        }
    }
}

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
        textView.isAutomaticLinkDetectionEnabled = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let newHash = markdown.hashValue ^ highlights.hashValue
        guard newHash != context.coordinator.lastContentHash else { return }

        let currentSelection = textView.selectedRange()
        textView.textStorage?.setAttributedString(buildAttributedString(markdown: markdown, highlights: highlights))

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

    let fullRange = NSRange(location: 0, length: result.length)

    #if os(iOS)
    let font = UIFont(name: "Georgia", size: 18) ?? UIFont.systemFont(ofSize: 18)
    let textColor = UIColor.label
    #else
    let font = NSFont(name: "Georgia", size: 18) ?? NSFont.systemFont(ofSize: 18)
    let textColor = NSColor.labelColor
    #endif

    result.addAttribute(.font, value: font, range: fullRange)
    result.addAttribute(.foregroundColor, value: textColor, range: fullRange)

    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.lineSpacing = 6
    result.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

    let nsString = result.string as NSString
    for highlight in highlights {
        if let range = resolveHighlightRange(highlight, in: result.string, nsString: nsString) {
            result.addAttribute(.backgroundColor, value: highlightColor(highlight.color), range: range)
        }
    }

    return result
}

private func resolveHighlightRange(_ highlight: Highlight, in content: String, nsString: NSString) -> NSRange? {
    guard highlight.startOffset >= 0,
          highlight.endOffset <= nsString.length else {
        return tryFuzzyMatch(highlight, in: content)
    }

    let proposedRange = NSRange(location: highlight.startOffset, length: highlight.endOffset - highlight.startOffset)
    let substring = nsString.substring(with: proposedRange)

    if substring == highlight.text {
        return proposedRange
    }

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
