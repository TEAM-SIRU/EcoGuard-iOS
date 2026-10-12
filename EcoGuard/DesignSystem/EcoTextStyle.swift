import SwiftUI
import UIKit

/// Figma Foundations 텍스트 스타일 `{이름} · {size}/{lineHeight} {Weight}`.
/// Redesign 2(823:574)에서 글씨를 한 단계씩 줄였다. 화면에 쓰인 실측값(본문 14/21, 리스트 15/22 · 13/19)을 따른다.
enum EcoTextStyle: CaseIterable {
    case title1
    case title2
    case title3
    case body1
    case body2
    case sub
    case caption
    case button
    case captionRegular
    /// Figma `Toast` 문구 · 정보 표 값 14/21 Medium.
    case body2Medium
    /// Figma `02 홈` 카드 제목(이번 주 청소·환경지킴이 공지) 15/22 Bold.
    case body1Bold
    /// Figma `02 홈` 섹션 제목(최근 청소 기록) 16/23 Bold.
    case title4
    /// Figma `02 홈` 기록 날짜 15/22 Bold.
    case title5
    /// Figma `02 홈` 전체보기 13/19 Medium.
    case subMedium
    /// Figma `02 홈` 적립 시간(+10분) 12/17 Medium.
    case captionMedium
    /// Figma `02 홈` 자세히 보기 14/21 Bold.
    case body2Bold
    /// Figma `Tab bar` 비선택 라벨 12/16 Medium.
    case caption2Medium
    /// Figma `Tab bar` 선택 라벨 12/16 Bold.
    case caption2Bold
    /// Figma `09-4 이의신청 결과 · 승인` 적립 시간(+10분, 823:4416) 28/30 Bold.
    case display

    /// 번들 폰트 PostScript 이름. `fc-scan`으로 OTF 파일에서 확인한 값이다.
    var fontName: String {
        switch self {
        case .title1, .title2, .title3, .caption, .button, .body1Bold, .title4, .title5, .body2Bold, .caption2Bold, .display:
            "NotoSansKR-Bold"
        case .body1, .body2Medium, .subMedium, .captionMedium, .caption2Medium:
            "NotoSansKR-Medium"
        case .body2, .sub, .captionRegular:
            "NotoSansKR-Regular"
        }
    }

    var size: CGFloat {
        switch self {
        case .title1: 22
        case .title2: 19
        case .title3: 17
        case .body1: 15
        case .body2: 14
        case .sub: 13
        case .caption: 12
        case .button: 15
        case .captionRegular: 12
        case .body2Medium: 14
        case .body1Bold: 15
        case .title4: 16
        case .title5: 15
        case .subMedium: 13
        case .captionMedium: 12
        case .body2Bold: 14
        case .display: 28
        case .caption2Medium, .caption2Bold: 12
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .title1: 30
        case .title2: 27
        case .title3: 25
        case .body1: 22
        case .body2: 21
        case .sub: 19
        case .caption: 17
        case .button: 22
        case .captionRegular: 17
        case .body2Medium: 21
        case .body1Bold: 22
        case .title4: 23
        case .title5: 22
        case .subMedium: 19
        case .captionMedium: 17
        case .body2Bold: 21
        case .display: 30
        case .caption2Medium, .caption2Bold: 16
        }
    }

    /// Figma letterSpacing -1%.
    var tracking: CGFloat {
        size * -0.01
    }

    var font: Font {
        // Dynamic Type 적용 여부가 정해지기 전까지 고정 크기로 둔다. 크기가 바뀌면 lineSpacing 계산도 함께 바뀌어야 한다.
        .custom(fontName, fixedSize: size)
    }

    /// `.lineSpacing`은 폰트 자체 줄높이 위에 더해지므로 Figma lineHeight와의 차이만 넣는다.
    /// Noto Sans KR 기본 줄높이(약 1.448em)보다 작은 Figma lineHeight(title1·title2·12pt 캡션 계열·display)는
    /// iOS에서 줄이지 못해 lineSpacing 0으로 고정되고 줄마다 0.4~1.9pt 커진다(display는 약 10pt).
    var lineSpacing: CGFloat {
        let uiFont = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        return max(0, lineHeight - uiFont.lineHeight)
    }
}

private struct EcoFontModifier: ViewModifier {
    let style: EcoTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .lineSpacing(style.lineSpacing)
            .tracking(style.tracking)
    }
}

extension View {
    func ecoFont(_ style: EcoTextStyle) -> some View {
        modifier(EcoFontModifier(style: style))
    }
}
