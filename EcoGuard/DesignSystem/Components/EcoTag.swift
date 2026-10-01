import SwiftUI

/// 작은 글자 태그.
/// - `new`: Figma `NEW` (249:12) 초록 배경 + 흰 글자, px10 py3 r8
/// - `tint`: Figma `모집 중` (255:584) · `신청 완료` (313:263) 연한 초록 배경, px6 py2 r6
struct EcoTag: View {
    enum Style {
        case new
        case tint
    }

    let title: LocalizedStringKey
    let style: Style

    var body: some View {
        Text(title)
            .ecoFont(.caption)
            .foregroundStyle(style.foreground)
            .lineLimit(1)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(style.background, in: RoundedRectangle(cornerRadius: style.cornerRadius))
    }
}

private extension EcoTag.Style {
    var foreground: Color {
        switch self {
        case .new: .ecoOnPrimary
        case .tint: .ecoPrimaryText
        }
    }

    var background: Color {
        switch self {
        case .new: .ecoPrimary
        case .tint: .ecoPrimaryTint
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .new: Metrics.newHorizontalPadding
        case .tint: Metrics.tintHorizontalPadding
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .new: Metrics.newVerticalPadding
        case .tint: Metrics.tintVerticalPadding
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .new: Metrics.newCornerRadius
        case .tint: Radius.tag
        }
    }
}

private enum Metrics {
    static let newHorizontalPadding: CGFloat = 10
    static let newVerticalPadding: CGFloat = 3
    static let newCornerRadius: CGFloat = 8
    static let tintHorizontalPadding: CGFloat = 6
    static let tintVerticalPadding: CGFloat = 2
}

#Preview {
    HStack(spacing: Spacing.sm) {
        EcoTag(title: "NEW", style: .new)
        EcoTag(title: "모집 중", style: .tint)
        EcoTag(title: "신청 완료", style: .tint)
    }
}
