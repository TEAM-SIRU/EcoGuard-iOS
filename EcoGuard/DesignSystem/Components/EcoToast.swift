import SwiftUI

/// Figma `Toast` (243:131). 어두운 배경 위 alert 아이콘 + 문구.
/// 오류가 아닌 안내(예: 복사 완료)는 Figma 정의가 없어 `icon: nil`로 문구만 보여준다.
struct EcoToast: View {
    /// 안내 토스트를 띄워 두는 시간.
    static let displayDuration: Duration = .seconds(2)

    /// VoiceOver 안내처럼 다른 곳에서도 같은 문구를 쓸 수 있게 `LocalizedStringResource`로 받는다.
    private let message: LocalizedStringResource
    private let icon: ImageResource?

    init(message: LocalizedStringResource, icon: ImageResource? = .iconAlertLarge) {
        self.message = message
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: Metrics.spacing) {
            if let icon {
                Image(icon)
                    .resizable()
                    .frame(width: Metrics.iconSize, height: Metrics.iconSize)
                    .foregroundStyle(Color.ecoToastIcon)
                    .accessibilityHidden(true)
            }
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
    VStack(spacing: Spacing.md) {
        EcoToast(message: "로그인하지 못했어요. 다시 시도해 주세요")
        EcoToast(message: "웹 주소를 복사했어요", icon: nil)
    }
    .padding(.horizontal, Spacing.screenHorizontal)
}
