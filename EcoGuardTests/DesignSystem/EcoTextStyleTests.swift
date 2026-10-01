import Testing
import UIKit
@testable import EcoGuard

@MainActor
struct EcoTextStyleTests {
    @Test(arguments: EcoTextStyle.allCases)
    func bundledFontIsRegistered(style: EcoTextStyle) {
        #expect(UIFont(name: style.fontName, size: style.size) != nil, "\(style.fontName) 미등록")
    }
}
