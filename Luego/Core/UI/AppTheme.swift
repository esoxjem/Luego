import SwiftUI
import Textual

extension Color {
    static let paperCream = Color(red: 250 / 255, green: 248 / 255, blue: 241 / 255)
    static let mascotPurple = Color(red: 223 / 255, green: 210 / 255, blue: 224 / 255)
    static let mascotPurpleInk = Color(red: 120 / 255, green: 98 / 255, blue: 125 / 255)

    static let gitHubBackground: Color = {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0, alpha: 1)
                : NSColor(red: 0xfd / 255.0, green: 0xfc / 255.0, blue: 0xf5 / 255.0, alpha: 1)
        })
        #else
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0, alpha: 1)
                : UIColor(red: 0xfd / 255.0, green: 0xfc / 255.0, blue: 0xf5 / 255.0, alpha: 1)
        })
        #endif
    }()
}

extension StructuredText.Style where Self == StructuredText.GitHubStyle {
    static var reader: StructuredText.GitHubStyle { .gitHub }
}

extension View {
    func readerContentStyle() -> some View {
        self
            .textual.structuredTextStyle(.reader)
            .textual.imageAttachmentLoader(.image())
            .textual.textSelection(.enabled)
    }
}

enum ReaderLayout {
    static func horizontalPadding(for containerWidth: CGFloat) -> CGFloat {
        #if os(macOS)
        let proportional = containerWidth * 0.15
        let maxContentWidth: CGFloat = 800
        let paddingForMaxWidth = max(24, (containerWidth - maxContentWidth) / 2)
        return max(proportional, paddingForMaxWidth)
        #else
        return 40
        #endif
    }
}
