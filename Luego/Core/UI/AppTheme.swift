import SwiftUI
import Textual
import UIKit

extension Color {
    static let paperCream = Color(red: 252 / 255, green: 252 / 255, blue: 253 / 255)
    static let mascotPurple = Color(red: 223 / 255, green: 210 / 255, blue: 224 / 255)
    static let mascotPurpleInk = Color(red: 120 / 255, green: 98 / 255, blue: 125 / 255)
    static let regularPanelBackground = paperCream
    static let barAccentFill = mascotPurple.opacity(0.72)
    static let barAccentInk = mascotPurpleInk
    static let regularSelectionFill = mascotPurple.opacity(0.5)
    static let regularSelectionInk = mascotPurpleInk
    static let regularOutline = Color.primary.opacity(0.18)
    static let regularGlassTint = mascotPurple.opacity(0.8)

    static let readerBackground: Color = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x18 / 255.0, green: 0x19 / 255.0, blue: 0x1d / 255.0, alpha: 1)
            : UIColor(regularPanelBackground)
    })
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
    case inlineTransparent
    case sidebarPanel

    fileprivate var chrome: AppNavigationChromeStyle {
        switch self {
        case .contentLargeTitle, .largeTransparent, .inlineTransparent:
            .transparent
        case .largePanel, .inlinePanel, .sidebarPanel:
            .panel
        }
    }

    fileprivate var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        switch self {
        case .inlinePanel, .inlineTransparent:
            .inline
        case .largePanel, .contentLargeTitle, .largeTransparent, .sidebarPanel:
            .large
        }
    }
}

enum AppNavigationAppearance {
    static func configurePlatformAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.regularPanelBackground)
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .font: UIFont.app(.navigationInlineTitle),
            .foregroundColor: UIColor.label
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.app(.navigationLargeTitle),
            .foregroundColor: UIColor.label
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

extension View {
    func appNavigationStyle(_ style: AppNavigationStyle) -> some View {
        self
            .appNavigationChrome(style.chrome)
            .navigationBarTitleDisplayMode(style.titleDisplayMode)
    }

    @ViewBuilder
    func appNavigationChrome(_ style: AppNavigationChromeStyle = .panel) -> some View {
        switch style {
        case .panel:
            self
                .toolbarBackground(Color.regularPanelBackground, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        case .transparent:
            self
                .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    func readerContentStyle(baseURL: URL? = nil) -> some View {
        self
            .textual.structuredTextStyle(.reader)
            .textual.imageAttachmentLoader(.image(relativeTo: baseURL))
            .textual.textSelection(.enabled)
    }
}

enum ReaderLayout {
    static func horizontalPadding(for containerWidth: CGFloat) -> CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            let maxContentWidth: CGFloat = 700
            let paddingForMaxWidth = max(56, (containerWidth - maxContentWidth) / 2)
            return paddingForMaxWidth
        }

        return 40
    }
}
