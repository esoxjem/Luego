import SwiftUI
import CoreText

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
}

extension Font {
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
#endif
