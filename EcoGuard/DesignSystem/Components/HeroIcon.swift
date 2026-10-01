import SwiftUI

/// 화면 가운데 큰 아이콘. 80 정사각 영역에 그린다.
/// - `logo`: Figma `Logo` (238:128). 64 아이콘만 둔다.
/// - `badge`: Figma 교사 안내 (309:43). 64 원 배경 가운데에 30 아이콘을 둔다.
/// - `result`: Figma 신청 결과 (246:119 check · 246:135 x). 64 아이콘을 `tint` 색으로 둔다.
struct HeroIcon: View {
    enum Style {
        case logo
        case badge
        case result(tint: Color)
    }

    let icon: ImageResource
    let style: Style
    /// 아이콘 색. 없으면 스타일 기본색(logo: primary, badge: caption)을 쓴다.
    var tint: Color?

    var body: some View {
        content
            .frame(width: Metrics.size, height: Metrics.size)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .logo:
            Image(icon)
                .resizable()
                .frame(width: Metrics.logoIconSize, height: Metrics.logoIconSize)
                .foregroundStyle(tint ?? Color.ecoPrimary)
        case .result(let resultTint):
            Image(icon)
                .resizable()
                .frame(width: Metrics.logoIconSize, height: Metrics.logoIconSize)
                .foregroundStyle(resultTint)
        case .badge:
            Image(icon)
                .resizable()
                .frame(width: Metrics.badgeIconSize, height: Metrics.badgeIconSize)
                .foregroundStyle(tint ?? Color.ecoTextCaption)
                .frame(width: Metrics.badgeSize, height: Metrics.badgeSize)
                .background(Color.ecoBadgeBackground, in: Circle())
        }
    }
}

private extension HeroIcon {
    enum Metrics {
        static let size: CGFloat = 80
        static let logoIconSize: CGFloat = 64
        static let badgeSize: CGFloat = 64
        static let badgeIconSize: CGFloat = 30
    }
}

#Preview {
    HStack(spacing: Spacing.lg) {
        HeroIcon(icon: .iconSprout, style: .logo)
        HeroIcon(icon: .iconList, style: .badge)
        HeroIcon(icon: .iconCheckHero, style: .result(tint: .ecoPrimary))
        HeroIcon(icon: .iconXHero, style: .result(tint: .ecoRejected))
    }
}
