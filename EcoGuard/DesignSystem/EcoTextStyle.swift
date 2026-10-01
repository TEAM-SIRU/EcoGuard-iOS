import SwiftUI
import UIKit

/// Figma Foundations 텍스트 스타일 `{이름} · {size}/{lineHeight} {Weight}`.
enum EcoTextStyle: CaseIterable {
    case title1
    case title2
    case title3
    case body1
    case body2
    case sub
    case caption
    case buttonLarge
    case button
    case captionRegular
    /// Figma `Toast` 문구 (컴포넌트) 15/22 Medium.
    case body2Medium
    /// Figma `02 홈` 카드 제목(이번 주 청소·환경지킴이 공지) 17/25 Bold.
    case body1Bold
    /// Figma `02 홈` 섹션 제목(최근 청소 기록) 18/26 Bold.
    case title4
    /// Figma `02 홈` 기록 날짜 16/23 Bold.
    case title5
    /// Figma `02 홈` 전체보기 14/20 Medium.
    case subMedium
    /// Figma `02 홈` 적립 시간(+10분) 13/18 Medium.
    case captionMedium
    /// Figma `02 홈` 자세히 보기·모집 인원 15/22 Bold.
    case body2Bold

    /// 번들 폰트 PostScript 이름. `fc-scan`으로 OTF 파일에서 확인한 값이다.
    var fontName: String {
        switch self {
        case .title1, .title2, .title3, .caption, .buttonLarge, .button, .body1Bold, .title4, .title5, .body2Bold:
            "NotoSansKR-Bold"
        case .body1, .body2Medium, .subMedium, .captionMedium:
            "NotoSansKR-Medium"
        case .body2, .sub, .captionRegular:
            "NotoSansKR-Regular"
        }
    }

    var size: CGFloat {
        switch self {
        case .title1: 26
        case .title2: 22
        case .title3: 20
        case .body1: 17
        case .body2: 15
        case .sub: 14
        case .caption: 13
        case .buttonLarge: 19
        case .button: 17
        case .captionRegular: 13
        case .body2Medium: 15
        case .body1Bold: 17
        case .title4: 18
        case .title5: 16
        case .subMedium: 14
        case .captionMedium: 13
        case .body2Bold: 15
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .title1: 36
        case .title2: 31
        case .title3: 29
        case .body1: 25
        case .body2: 22
        case .sub: 20
        case .caption: 18
        case .buttonLarge: 26
        case .button: 24
        case .captionRegular: 18
        case .body2Medium: 22
        case .body1Bold: 25
        case .title4: 26
        case .title5: 23
        case .subMedium: 20
        case .captionMedium: 18
        case .body2Bold: 22
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
    /// Noto Sans KR 기본 줄높이(약 1.448em)보다 작은 Figma lineHeight(title1·title2·sub·caption·buttonLarge·button·captionRegular)는
    /// iOS에서 줄이지 못해 lineSpacing 0으로 고정되고 줄마다 0.3~1.7pt 커진다(sub 0.27pt, 나머지 0.6~1.7pt).
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
