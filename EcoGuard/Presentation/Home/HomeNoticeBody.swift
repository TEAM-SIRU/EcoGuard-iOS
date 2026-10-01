import SwiftUI

/// 공지 본문 마크다운 → 화면용 텍스트. `**`로 감싼 부분은 굵고 진하게, 줄바꿈은 그대로 둔다.
/// Figma 본문 #4E5968 · 강조 #191F28은 변수가 아니라 글자 토큰으로 대체했다.
enum HomeNoticeBody {
    static func attributed(from markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var text = (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
        text.foregroundColor = .ecoTextSub
        let strongRanges = text.runs
            .filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
            .map(\.range)
        for range in strongRanges {
            text[range].foregroundColor = .ecoTextPrimary
            text[range].font = EcoTextStyle.body2Bold.font
        }
        return text
    }
}
