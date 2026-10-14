import AppKit
import CoreText
import OSLog
import SwiftUI

enum TeclaFonts {
    private static let weightAxis = 0x7767_6874
    private static let widthAxis = 0x7764_7468

    static let logger = Logger(subsystem: "com.giancarlosisasi.dailyzgt", category: "fonts")

    static let registration: (registered: [String], failed: [String]) = {
        var registered: [String] = []
        var failed: [String] = []
        for family in TeclaTokens.Fonts.all {
            guard let url = Bundle.main.url(forResource: family.file, withExtension: nil) else {
                failed.append(family.file)
                continue
            }
            var error: Unmanaged<CFError>?
            let done = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
            if done || code == CTFontManagerError.alreadyRegistered.rawValue {
                registered.append(family.file)
            } else {
                failed.append(family.file)
            }
        }
        return (registered, failed)
    }()

    static var registeredFiles: [String] { registration.registered }

    @discardableResult
    static func register() -> [String] {
        registeredFiles
    }

    static func logRegistration() {
        let result = registration
        logger.info("Fonts registered: \(result.registered.count, privacy: .public), failed: \(result.failed.count, privacy: .public)")
    }

    static func ctFont(family: TeclaFontFamily, size: CGFloat, weight: Int, tabularDigits: Bool = false) -> CTFont {
        register()
        let base = CTFontCreateWithName(family.family as CFString, size, nil)
        var variation: [Int: Double] = [weightAxis: Double(weight)]
        if let width = family.width, axes(of: base).contains(widthAxis) {
            variation[widthAxis] = width
        }
        var attributes: [CFString: Any] = [
            kCTFontFamilyNameAttribute: family.family,
            kCTFontVariationAttribute: variation,
        ]
        if tabularDigits {
            attributes[kCTFontFeatureSettingsAttribute] = [[
                kCTFontFeatureTypeIdentifierKey: kNumberSpacingType,
                kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector,
            ]]
        }
        return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(attributes as CFDictionary), size, nil)
    }

    static func ctFont(_ style: TeclaTextStyle, weight: TeclaWeight? = nil, tabularDigits: Bool = false) -> CTFont {
        ctFont(
            family: style.family,
            size: style.size,
            weight: weight?.rawValue ?? style.weight,
            tabularDigits: tabularDigits
        )
    }

    static func font(_ style: TeclaTextStyle, weight: TeclaWeight? = nil) -> Font {
        Font(ctFont(style, weight: weight))
    }

    static func nsFont(_ style: TeclaTextStyle, weight: TeclaWeight? = nil, tabularDigits: Bool = false) -> NSFont {
        ctFont(style, weight: weight, tabularDigits: tabularDigits) as NSFont
    }

    static func weight(of font: CTFont) -> Int? {
        let variation = CTFontCopyVariation(font) as? [Int: Double] ?? [:]
        if let value = variation[weightAxis] {
            return Int(value.rounded())
        }
        return defaultWeight(of: font)
    }

    private static func axes(of font: CTFont) -> [Int] {
        let list = CTFontCopyVariationAxes(font) as? [[CFString: Any]] ?? []
        return list.compactMap { $0[kCTFontVariationAxisIdentifierKey] as? Int }
    }

    private static func defaultWeight(of font: CTFont) -> Int? {
        let list = CTFontCopyVariationAxes(font) as? [[CFString: Any]] ?? []
        let axis = list.first { $0[kCTFontVariationAxisIdentifierKey] as? Int == weightAxis }
        return (axis?[kCTFontVariationAxisDefaultValueKey] as? Double).map { Int($0.rounded()) }
    }
}
