import SwiftUI
import MarkdownUI

extension Color {
    static let gitHubBackground = Color(
        light: .white,
        dark: Color(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0)
    )
}

extension Theme {
    static let reader = Theme.gitHub
        .text {
            FontSize(18)
        }
}
