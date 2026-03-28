import SwiftUI
import CoreText

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppFontFamily {
    case lora
    case nunito
    case system
}

enum AppTextRole {
    case body
    case navigationLargeTitle
    case navigationInlineTitle
    case sidebarTitle
    case sidebarItem
    case listTitle
    case listExcerpt
    case listMetadata
    case emptyStateTitle
    case emptyStateBody
    case actionLabel
    case auxiliaryStatus
    case sheetTitle

    fileprivate var family: AppFontFamily {
        switch self {
        case .navigationLargeTitle, .sidebarTitle, .listTitle, .emptyStateTitle, .sheetTitle:
            .lora
        case .navigationInlineTitle, .listMetadata, .auxiliaryStatus:
            .system
        case .body, .sidebarItem, .listExcerpt, .emptyStateBody, .actionLabel:
            .nunito
        }
    }

    fileprivate var weight: Font.Weight {
        switch self {
        case .navigationLargeTitle, .sidebarTitle:
            .regular
        case .navigationInlineTitle:
            .regular
        case .sidebarItem:
            .regular
        case .actionLabel, .sheetTitle:
            .semibold
        default:
            .regular
        }
    }

    fileprivate var textStyle: Font.TextStyle {
        switch self {
        case .body:
            .body
        case .navigationLargeTitle, .sidebarTitle:
            .largeTitle
        case .navigationInlineTitle, .listTitle:
            .headline
        case .sidebarItem:
            .body
        case .listExcerpt, .actionLabel:
            .subheadline
        case .listMetadata, .auxiliaryStatus:
            .caption
        case .emptyStateTitle:
            .title2
        case .emptyStateBody:
            .callout
        case .sheetTitle:
            .title3
        }
    }

    fileprivate var basePointSize: CGFloat {
        switch self {
        case .body:
            17
        case .navigationLargeTitle, .sidebarTitle:
            34
        case .navigationInlineTitle, .sidebarItem, .listTitle:
            17
        case .listExcerpt, .actionLabel:
            15
        case .listMetadata, .auxiliaryStatus:
            12
        case .emptyStateTitle:
            22
        case .emptyStateBody:
            16
        case .sheetTitle:
            20
        }
    }

    fileprivate var macOSPointSize: CGFloat {
        switch self {
        case .body:
            16
        case .sidebarItem:
            16
        case .listTitle:
            16
        case .listExcerpt:
            13.5
        case .listMetadata:
            11.5
        case .emptyStateBody:
            15
        default:
            basePointSize
        }
    }

    fileprivate var selectedWeight: Font.Weight {
        switch self {
        case .sidebarItem:
            .semibold
        default:
            weight
        }
    }
}

enum AppTypography {
    static let loraPostScriptName = "Lora-Regular"
    static let nunitoPostScriptName = "NunitoSans-12ptRegular"
    private static let loraFileName = "Lora"
    private static let nunitoFileName = "NunitoSans"
    private static let loraFileExtension = "ttf"
    private static let nunitoFileExtension = "ttf"
    static let loraWeightAxisIdentifier = fourCharacterCode("wght")
    static let nunitoWeightAxisIdentifier = fourCharacterCode("wght")

    static func registerFonts() {
        registerFont(named: loraFileName, extension: loraFileExtension)
        registerFont(named: nunitoFileName, extension: nunitoFileExtension)
    }

    static func fontSize(for textStyle: Font.TextStyle) -> CGFloat {
        switch textStyle {
        case .largeTitle:
            34
        case .title:
            28
        case .title2:
            22
        case .title3:
            20
        case .headline:
            17
        case .subheadline:
            15
        case .body:
            14
        case .callout:
            14
        case .footnote:
            13
        case .caption:
            12
        case .caption2:
            11
        @unknown default:
            17
        }
    }

    static func variableFontAxisValue(for weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight:
            400
        case .thin:
            400
        case .light:
            400
        case .regular:
            400
        case .medium:
            500
        case .semibold:
            600
        case .bold:
            700
        case .heavy:
            700
        case .black:
            700
        default:
            400
        }
    }

    private static func fourCharacterCode(_ value: String) -> Int {
        value.utf8.reduce(0) { partialResult, character in
            (partialResult << 8) | Int(character)
        }
    }

    private static func registerFont(named fileName: String, extension fileExtension: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            return
        }

        var registrationError: Unmanaged<CFError>?
        let didRegister = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registrationError)

        if didRegister {
            return
        }

        guard let error = registrationError?.takeRetainedValue() else {
            return
        }

        let alreadyRegisteredCode = CTFontManagerError.alreadyRegistered.rawValue
        let domain = CFErrorGetDomain(error) as String
        let code = CFErrorGetCode(error)

        if domain == kCTFontManagerErrorDomain as String, code == alreadyRegisteredCode {
            return
        }
    }

    static func font(for role: AppTextRole, isEmphasized: Bool = false) -> Font {
        #if os(iOS)
        Font(uiFont(for: role, isEmphasized: isEmphasized))
        #elseif os(macOS)
        Font(nsFont(for: role, isEmphasized: isEmphasized))
        #else
        switch role.family {
        case .lora, .nunito:
            .custom(
                postScriptName(for: role.family),
                size: role.basePointSize,
                relativeTo: role.textStyle
            )
        case .system:
            .system(role.textStyle, design: .default)
        }
        #endif
    }

    private static func postScriptName(for family: AppFontFamily) -> String {
        switch family {
        case .lora:
            loraPostScriptName
        case .nunito:
            nunitoPostScriptName
        case .system:
            ""
        }
    }

    private static func axisIdentifier(for family: AppFontFamily) -> Int {
        switch family {
        case .lora:
            loraWeightAxisIdentifier
        case .nunito:
            nunitoWeightAxisIdentifier
        case .system:
            0
        }
    }

    private static func resolvedWeight(for role: AppTextRole, isEmphasized: Bool) -> Font.Weight {
        if isEmphasized {
            return role.selectedWeight
        }

        return role.weight
    }
}

extension Font {
    static func app(_ role: AppTextRole, emphasized: Bool = false) -> Font {
        AppTypography.font(for: role, isEmphasized: emphasized)
    }

    static func lora(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        #if os(iOS)
        Font(UIFont.lora(forTextStyle: textStyle.uiTextStyle, weight: weight))
        #elseif os(macOS)
        Font(NSFont.lora(size: AppTypography.fontSize(for: textStyle), weight: weight))
        #else
        .custom(
            AppTypography.loraPostScriptName,
            size: AppTypography.fontSize(for: textStyle),
            relativeTo: textStyle
        )
        #endif
    }

    static func nunito(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        #if os(iOS)
        Font(UIFont.nunito(forTextStyle: textStyle.uiTextStyle, weight: weight))
        #elseif os(macOS)
        Font(NSFont.nunito(size: AppTypography.fontSize(for: textStyle), weight: weight))
        #else
        .custom(
            AppTypography.nunitoPostScriptName,
            size: AppTypography.fontSize(for: textStyle),
            relativeTo: textStyle
        )
        #endif
    }
}

#if os(iOS)
extension UIFont {
    static func app(_ role: AppTextRole, emphasized: Bool = false) -> UIFont {
        AppTypography.uiFont(for: role, isEmphasized: emphasized)
    }

    static func lora(forTextStyle textStyle: UIFont.TextStyle, weight: Font.Weight = .regular) -> UIFont {
        let pointSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle).pointSize
        let axisValue = AppTypography.variableFontAxisValue(for: weight)
        let variationAttributeName = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: AppTypography.loraPostScriptName,
            variationAttributeName: [AppTypography.loraWeightAxisIdentifier: axisValue]
        ])
        let font = UIFont(descriptor: descriptor, size: pointSize)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }

    static func nunito(forTextStyle textStyle: UIFont.TextStyle, weight: Font.Weight = .regular) -> UIFont {
        let pointSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle).pointSize
        let axisValue = AppTypography.variableFontAxisValue(for: weight)
        let variationAttributeName = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: AppTypography.nunitoPostScriptName,
            variationAttributeName: [AppTypography.nunitoWeightAxisIdentifier: axisValue]
        ])
        let font = UIFont(descriptor: descriptor, size: pointSize)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}

extension AppTypography {
    static func uiFont(for role: AppTextRole, isEmphasized: Bool = false) -> UIFont {
        let weight = resolvedWeight(for: role, isEmphasized: isEmphasized)
        switch role.family {
        case .lora:
            return UIFont.lora(forTextStyle: role.textStyle.uiTextStyle, weight: weight)
        case .nunito:
            return UIFont.nunito(forTextStyle: role.textStyle.uiTextStyle, weight: weight)
        case .system:
            return UIFont.preferredFont(forTextStyle: role.textStyle.uiTextStyle)
        }
    }
}

private extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle:
            .largeTitle
        case .title:
            .title1
        case .title2:
            .title2
        case .title3:
            .title3
        case .headline:
            .headline
        case .subheadline:
            .subheadline
        case .body:
            .body
        case .callout:
            .callout
        case .footnote:
            .footnote
        case .caption:
            .caption1
        case .caption2:
            .caption2
        @unknown default:
            .body
        }
    }
}
#elseif os(macOS)
extension NSFont {
    static func app(_ role: AppTextRole, emphasized: Bool = false) -> NSFont {
        AppTypography.nsFont(for: role, isEmphasized: emphasized)
    }

    static func lora(size: CGFloat, weight: Font.Weight = .regular) -> NSFont {
        let axisValue = AppTypography.variableFontAxisValue(for: weight)
        let variationAttributeName = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: AppTypography.loraPostScriptName,
            variationAttributeName: [AppTypography.loraWeightAxisIdentifier: axisValue]
        ])

        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont(name: AppTypography.loraPostScriptName, size: size)
            ?? .systemFont(ofSize: size)
    }

    static func nunito(size: CGFloat, weight: Font.Weight = .regular) -> NSFont {
        let axisValue = AppTypography.variableFontAxisValue(for: weight)
        let variationAttributeName = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: AppTypography.nunitoPostScriptName,
            variationAttributeName: [AppTypography.nunitoWeightAxisIdentifier: axisValue]
        ])

        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont(name: AppTypography.nunitoPostScriptName, size: size)
            ?? .systemFont(ofSize: size)
    }
}

extension AppTypography {
    static func nsFont(for role: AppTextRole, isEmphasized: Bool = false) -> NSFont {
        let weight = resolvedWeight(for: role, isEmphasized: isEmphasized)
        let size = role.macOSPointSize
        if role.family == .system {
            return NSFont.systemFont(ofSize: size, weight: nsFontWeight(for: weight))
        }
        let variationAttributeName = NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = NSFontDescriptor(fontAttributes: [
            .name: postScriptName(for: role.family),
            .size: size,
            variationAttributeName: [axisIdentifier(for: role.family): variableFontAxisValue(for: weight)]
        ])

        return NSFont(descriptor: descriptor, size: size)
            ?? NSFont(name: postScriptName(for: role.family), size: size)
            ?? .systemFont(ofSize: size)
    }

    private static func nsFontWeight(for weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight:
            .ultraLight
        case .thin:
            .thin
        case .light:
            .light
        case .regular:
            .regular
        case .medium:
            .medium
        case .semibold:
            .semibold
        case .bold:
            .bold
        case .heavy:
            .heavy
        case .black:
            .black
        default:
            .regular
        }
    }
}
#endif
