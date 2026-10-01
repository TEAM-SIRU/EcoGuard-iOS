import SwiftUI

/// Figma `02 홈 · 조회 실패` (514:78) · `활동 제외 안내` (514:224).
/// 홈은 루트 화면이라 Figma의 뒤로가기 버튼은 두지 않는다.
struct HomeMessageView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let primaryAction: () async -> Void
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Text(title)
                .ecoFont(.title1)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screenHorizontal)
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                VStack(spacing: Spacing.sm) {
                    EcoButton(primaryTitle) {
                        await primaryAction()
                    }
                    EcoButton("공지 보기", style: .secondary, action: secondaryAction)
                }
            }
        }
    }
}
