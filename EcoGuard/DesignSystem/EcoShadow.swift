import SwiftUI

/// Figma `02 홈` 카드 그림자. 색은 alpha가 들어간 colorset이다.
enum EcoShadow {
    /// 일반 카드(오늘의 청소·이번 주 청소·기록). 0 / 2 / 10, rgba(26,33,31,0.06).
    case card
    /// 메인 공지 카드. 0 / 4 / 16, rgba(26,31,41,0.08).
    case notice

    var color: Color {
        switch self {
        case .card: .ecoShadowCard
        case .notice: .ecoShadowNotice
        }
    }

    /// Figma blur. SwiftUI `radius`는 blur의 절반이다.
    var radius: CGFloat {
        switch self {
        case .card: 5
        case .notice: 8
        }
    }

    var offsetY: CGFloat {
        switch self {
        case .card: 2
        case .notice: 4
        }
    }
}

extension View {
    func ecoShadow(_ shadow: EcoShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.offsetY)
    }
}
