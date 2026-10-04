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

    /// Figma `02 홈` · `09-4 이의신청 결과 · 승인`(display) 프레임에서 읽은 size/lineHeight/weight.
    @Test(arguments: [
        (EcoTextStyle.body1Bold, CGFloat(17), CGFloat(25), "NotoSansKR-Bold"),
        (.title4, 18, 26, "NotoSansKR-Bold"),
        (.title5, 16, 23, "NotoSansKR-Bold"),
        (.subMedium, 14, 20, "NotoSansKR-Medium"),
        (.captionMedium, 13, 18, "NotoSansKR-Medium"),
        (.body2Bold, 15, 22, "NotoSansKR-Bold"),
        (.caption2Medium, 12, 16, "NotoSansKR-Medium"),
        (.caption2Bold, 12, 16, "NotoSansKR-Bold"),
        (.display, 32, 34, "NotoSansKR-Bold")
    ])
    func homeStyleMatchesFigma(style: EcoTextStyle, size: CGFloat, lineHeight: CGFloat, fontName: String) {
        #expect(style.size == size)
        #expect(style.lineHeight == lineHeight)
        #expect(style.fontName == fontName)
    }
}
