import SwiftUI

/// 불러오는 중 자리 표시 블록. Figma `02 홈 · 로딩` (823:4482) Skeleton. 줄은 grey/150 radius 12, 카드·행은 흰색 radius 20.
struct EcoSkeleton: View {
    enum Kind {
        /// 160 × 24
        case shortLine
        /// 220 × 24
        case longLine
        /// 풀와이드 × 156
        case card
        /// 풀와이드 × 72
        case row
    }

    let kind: Kind

    var body: some View {
        RoundedRectangle(cornerRadius: kind.cornerRadius)
            .fill(kind.fill)
            .frame(width: kind.width, height: kind.height)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }
}

private extension EcoSkeleton.Kind {
    var width: CGFloat? {
        switch self {
        case .shortLine: Metrics.shortLineWidth
        case .longLine: Metrics.longLineWidth
        case .card, .row: nil
        }
    }

    var fill: Color {
        switch self {
        case .shortLine, .longLine: .ecoButtonFill
        case .card, .row: .ecoCard
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .shortLine, .longLine: Radius.tile
        case .card, .row: Radius.card
        }
    }

    var height: CGFloat {
        switch self {
        case .shortLine, .longLine: Metrics.lineHeight
        case .card: Metrics.cardHeight
        case .row: Metrics.rowHeight
        }
    }
}

private enum Metrics {
    static let shortLineWidth: CGFloat = 160
    static let longLineWidth: CGFloat = 220
    static let lineHeight: CGFloat = 24
    static let cardHeight: CGFloat = 156
    static let rowHeight: CGFloat = 72
}

#Preview {
    VStack(spacing: Spacing.xxl) {
        EcoSkeleton(kind: .shortLine)
        EcoSkeleton(kind: .card)
        EcoSkeleton(kind: .row)
        EcoSkeleton(kind: .longLine)
    }
    .padding(Spacing.screenHorizontal)
}
