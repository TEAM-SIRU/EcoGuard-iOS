import SwiftUI

/// 화면 가운데 큰 아이콘. 80 정사각 영역에 그린다.
/// - `logo`: Figma `Logo` (238:128). 64 아이콘만 둔다.
/// - `badge`: Figma 교사 안내 (309:43). 64 원 배경 가운데에 30 아이콘을 둔다.
struct HeroIcon: View {
    enum Style {
        case logo
        case badge
    }

    let icon: ImageResource
    let style: Style

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
                .foregroundStyle(Color.ecoPrimary)
        case .badge:
            Image(icon)
                .resizable()
                .frame(width: Metrics.badgeIconSize, height: Metrics.badgeIconSize)
                .foregroundStyle(Color.ecoTextCaption)
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
    }
}
