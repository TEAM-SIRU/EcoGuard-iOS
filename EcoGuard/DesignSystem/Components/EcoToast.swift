import SwiftUI

/// Figma `Toast` (243:131). 어두운 배경 위 alert 아이콘 + 문구.
struct EcoToast: View {
    let message: LocalizedStringKey

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            Image(.iconAlertLarge)
                .resizable()
                .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                .foregroundStyle(Color.ecoToastIcon)
                .accessibilityHidden(true)
            Text(message)
                .ecoFont(.body2Medium)
                .foregroundStyle(Color.ecoOnToast)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.lg)
        .frame(minHeight: Metrics.height)
        .background(Color.ecoToastBackground, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}

private extension EcoToast {
    enum Metrics {
        static let height: CGFloat = 56
        static let spacing: CGFloat = 10
        static let iconSize: CGFloat = 20
        static let cornerRadius: CGFloat = 14
    }
}

#Preview {
    EcoToast(message: "로그인하지 못했어요. 다시 시도해 주세요")
        .padding(.horizontal, Spacing.screenHorizontal)
}
