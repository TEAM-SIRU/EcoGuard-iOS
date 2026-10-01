import CoreText
import Testing
import UIKit
@testable import EcoGuard

@MainActor
struct EcoTextStyleTests {
    @Test(arguments: EcoTextStyle.allCases)
    func bundledFontIsRegistered(style: EcoTextStyle) {
        #expect(UIFont(name: style.fontName, size: style.size) != nil, "\(style.fontName) 미등록")
    }

    /// 번들 폰트는 KS X 1001 완성형 2,350자 서브셋이다. 서브셋 밖 글자는 시스템 폰트로 대체돼야 한다.
    @Test(arguments: ["똠", "뷁"])
    func syllableOutsideSubsetFallsBackToSystemFont(text: String) throws {
        let font = try #require(UIFont(name: EcoTextStyle.body2.fontName, size: EcoTextStyle.body2.size))
        let resolved = CTFontCreateForString(font, text as CFString, CFRange(location: 0, length: text.utf16.count))
        let resolvedName = CTFontCopyPostScriptName(resolved) as String
        #expect(resolvedName != EcoTextStyle.body2.fontName)
        let characters = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        #expect(CTFontGetGlyphsForCharacters(resolved, characters, &glyphs, characters.count))
    }

    @Test(arguments: ["가", "환경지킴이", "·"])
    func textInsideSubsetUsesBundledFont(text: String) throws {
        let font = try #require(UIFont(name: EcoTextStyle.body2.fontName, size: EcoTextStyle.body2.size))
        let resolved = CTFontCreateForString(font, text as CFString, CFRange(location: 0, length: text.utf16.count))
        #expect(CTFontCopyPostScriptName(resolved) as String == EcoTextStyle.body2.fontName)
    }
}
