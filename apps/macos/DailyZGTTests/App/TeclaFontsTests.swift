import AppKit
import CoreText
import Foundation
import Testing
@testable import DailyZGT

@Suite
@MainActor
struct TeclaFontsTests {
    @Test
    func theAppBundleHasEachFontFileAndItsLicense() throws {
        for family in TeclaTokens.Fonts.all {
            let url = try #require(Bundle.main.url(forResource: family.file, withExtension: nil), "\(family.file)")
            let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            #expect(size > 50_000, "\(family.file)")
            let license = family.family.replacingOccurrences(of: " ", with: "") + "-OFL"
            #expect(Bundle.main.url(forResource: license, withExtension: "txt") != nil, "\(license)")
        }
    }

    @Test
    func theAppRegistersEachFontFile() {
        #expect(TeclaFonts.register() == TeclaTokens.Fonts.all.map(\.file))
    }

    @Test
    func theRegistrationCountsTheFilesThatRegisteredAndThatFailed() {
        let result = TeclaFonts.registration

        #expect(result.registered.count == 3)
        #expect(result.failed.isEmpty)
        #expect(result.registered.count + result.failed.count == TeclaTokens.Fonts.all.count)
    }

    @Test
    func eachFamilyAndWeightResolvesToTheBundledFont() throws {
        for family in TeclaTokens.Fonts.all {
            let bundled = try #require(Bundle.main.url(forResource: family.file, withExtension: nil))
            for weight in family.weights {
                let font = TeclaFonts.ctFont(family: family, size: 13, weight: weight)
                let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL

                #expect(CTFontCopyFamilyName(font) as String == family.family, "\(family.family) \(weight)")
                #expect(TeclaFonts.weight(of: font) == weight, "\(family.family) \(weight)")
                #expect(url?.resolvingSymlinksInPath() == bundled.resolvingSymlinksInPath(), "\(family.family) \(weight)")
            }
        }
    }

    @Test
    func theMonoFontHasTheWidthOfTheToken() {
        TeclaFonts.register()
        let tokenFont = TeclaFonts.nsFont(TeclaTokens.TextStyles.code)
        let attributes: [CFString: Any] = [
            kCTFontFamilyNameAttribute: TeclaTokens.Fonts.mono.family,
            kCTFontVariationAttribute: [0x7767_6874: 400.0, 0x7764_7468: 100.0],
        ]
        let narrowFont = CTFontCreateWithFontDescriptor(
            CTFontDescriptorCreateWithAttributes(attributes as CFDictionary),
            TeclaTokens.TextStyles.code.size,
            nil
        ) as NSFont
        let text = "0000000000"
        let tokenWidth = NSAttributedString(string: text, attributes: [.font: tokenFont]).size().width
        let narrowWidth = NSAttributedString(string: text, attributes: [.font: narrowFont]).size().width

        #expect(TeclaTokens.Fonts.mono.width == 112.5)
        #expect(TeclaTokens.Fonts.text.width == nil)
        #expect(tokenWidth > narrowWidth)
    }

    @Test
    func aWeightChangesTheGlyphWidth() {
        let regular = TeclaFonts.nsFont(TeclaTokens.TextStyles.panel, weight: .regular)
        let bold = TeclaFonts.nsFont(TeclaTokens.TextStyles.panel, weight: .bold)
        let text = "Revisar el contrato de Lima"
        let regularWidth = NSAttributedString(string: text, attributes: [.font: regular]).size().width
        let boldWidth = NSAttributedString(string: text, attributes: [.font: bold]).size().width

        #expect(boldWidth > regularWidth)
    }
}
