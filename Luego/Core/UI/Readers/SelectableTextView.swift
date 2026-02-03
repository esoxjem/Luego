import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct SelectableTextView: View {
    let markdown: String

    var body: some View {
        SelectableTextViewRepresentable(markdown: markdown)
    }
}

#if os(iOS)

struct SelectableTextViewRepresentable: UIViewRepresentable {
    let markdown: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)
        textView.dataDetectorTypes = .link
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let newHash = markdown.hashValue
        guard newHash != context.coordinator.lastContentHash else { return }

        textView.attributedText = buildAttributedString(markdown: markdown)
        context.coordinator.lastContentHash = newHash
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingCompressedSize.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    class Coordinator {
        var lastContentHash: Int = 0
    }
}

#else

struct SelectableTextViewRepresentable: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 24, height: 16)
        textView.isAutomaticLinkDetectionEnabled = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let newHash = markdown.hashValue
        guard newHash != context.coordinator.lastContentHash else { return }

        textView.textStorage?.setAttributedString(buildAttributedString(markdown: markdown))
        context.coordinator.lastContentHash = newHash
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastContentHash: Int = 0
    }
}

#endif

private func buildAttributedString(markdown: String) -> NSAttributedString {
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

    return result
}
