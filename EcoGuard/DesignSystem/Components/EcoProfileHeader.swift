import SwiftUI

/// Figma `12 전체` `Profile` (512:44). 이름 두 글자 원형 아바타 56 + 이름(title3) + 소속(sub).
struct EcoProfileHeader: View {
    let initials: String
    let name: String
    let caption: String

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Text(initials)
                .ecoFont(.body1Bold)
                .foregroundStyle(Color.ecoPrimaryText)
                .lineLimit(1)
                .frame(width: Metrics.avatarSize, height: Metrics.avatarSize)
                .background(Color.ecoPrimaryTint, in: Circle())
                .accessibilityHidden(true)
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

private enum Metrics {
    static let avatarSize: CGFloat = 56
    static let spacing: CGFloat = 14
    static let textSpacing: CGFloat = 2
}

#Preview {
    EcoProfileHeader(initials: "민준", name: "최민준", caption: "2학년 3반 · 환경지킴이")
        .padding(.horizontal, Spacing.screenHorizontal)
}
