import SwiftUI

/// Figma `12 마이페이지` `Profile` (823:2062). 기본 아바타 56 + 이름(title3) + 소속(sub).
struct EcoProfileHeader: View {
    let name: String
    let caption: String

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            DefaultAvatar()
            VStack(alignment: .leading, spacing: Metrics.textSpacing) {
                Text(name)
                    .ecoFont(.title3)
                    .foregroundStyle(Color.ecoTextPrimary)
                Text(caption)
                    .ecoFont(.sub)
                    .foregroundStyle(Color.ecoTextCaption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Figma `Avatar · 기본`. grey/300 원 안에 흰 머리(20, 위 11)와 몸(36 × 26, 위 35)을 원 밖으로 잘라 그린다.
private struct DefaultAvatar: View {
    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(Color.ecoBorderStrong)
            Circle()
                .fill(Color.ecoCard)
                .frame(width: Metrics.headSize, height: Metrics.headSize)
                .offset(y: Metrics.headTop)
            Ellipse()
                .fill(Color.ecoCard)
                .frame(width: Metrics.bodyWidth, height: Metrics.bodyHeight)
                .offset(y: Metrics.bodyTop)
        }
        .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private enum Metrics {
    static let avatarSize: CGFloat = 56
    static let headSize: CGFloat = 20
    static let headTop: CGFloat = 11
    static let bodyWidth: CGFloat = 36
    static let bodyHeight: CGFloat = 26
    static let bodyTop: CGFloat = 35
    static let spacing: CGFloat = 14
    static let textSpacing: CGFloat = 2
}

#Preview {
    EcoProfileHeader(name: "최민준", caption: "2학년 3반 · 환경지킴이")
        .padding(.horizontal, Spacing.screenHorizontal)
}
