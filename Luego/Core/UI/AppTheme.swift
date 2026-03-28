import SwiftUI
import Textual

#if os(iOS)
import UIKit
#endif

extension Color {
    static let paperCream = Color(red: 250 / 255, green: 248 / 255, blue: 241 / 255)
    static let mascotPurple = Color(red: 223 / 255, green: 210 / 255, blue: 224 / 255)
    static let mascotPurpleInk = Color(red: 120 / 255, green: 98 / 255, blue: 125 / 255)
    static let regularPanelBackground = paperCream
    static let regularSelectionFill = mascotPurple.opacity(0.5)
    static let regularSelectionInk = mascotPurpleInk
    static let regularOutline = Color.primary.opacity(0.18)
    static let regularGlassTint = mascotPurple.opacity(0.8)

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

enum AppNavigationChromeStyle {
    case panel
    case transparent
}

enum AppNavigationStyle {
    case largePanel
    case contentLargeTitle
    case largeTransparent
    case inlinePanel
    case sidebarPanel

    fileprivate var chrome: AppNavigationChromeStyle {
        switch self {
        case .contentLargeTitle, .largeTransparent:
            .transparent
        case .largePanel, .inlinePanel, .sidebarPanel:
            .panel
        }
    }

    #if os(iOS)
    fileprivate var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .inlinePanel:
            .inline
        case .largePanel, .contentLargeTitle, .largeTransparent, .sidebarPanel:
            .large
        }
    }
    #endif
}

enum AppNavigationAppearance {
    static func configurePlatformAppearance() {
        #if os(iOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(
            red: 250 / 255,
            green: 248 / 255,
            blue: 241 / 255,
            alpha: 1
        )
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.app(.navigationLargeTitle),
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        #endif
    }
}

extension View {
    @ViewBuilder
    func appNavigationStyle(_ style: AppNavigationStyle) -> some View {
        #if os(iOS)
        self
            .appNavigationChrome(style.chrome)
            .navigationBarTitleDisplayMode(style.titleDisplayMode)
        #elseif os(macOS)
        self
            .appNavigationChrome()
        #else
        self
        #endif
    }

    @ViewBuilder
    func appNavigationChrome(_ style: AppNavigationChromeStyle = .panel) -> some View {
        #if os(iOS)
        switch style {
        case .panel:
            self
                .toolbarBackground(Color.regularPanelBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        case .transparent:
            self
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        #elseif os(macOS)
        self
            .toolbar(removing: .sidebarToggle)
        #else
        self
        #endif
    }

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
