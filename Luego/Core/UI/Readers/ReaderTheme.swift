import SwiftUI
import Textual

extension Color {
    static let gitHubBackground: Color = {
        #if os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
                ? NSColor(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0, alpha: 1)
                : .white
        })
        #else
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0, alpha: 1)
                : .white
        })
        #endif
    }()
}

extension StructuredText.Style where Self == StructuredText.GitHubStyle {
    static var reader: StructuredText.GitHubStyle { .gitHub }
}
