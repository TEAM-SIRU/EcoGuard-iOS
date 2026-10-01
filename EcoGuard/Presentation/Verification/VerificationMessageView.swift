import SwiftUI

/// Figma `06-5 업로드 실패` (514:20) · `06-6 시간 초과` (514:49). 제목·설명과 하단 버튼 두 개.
struct VerificationMessageView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let primaryAction: () async -> Void
    let back: () -> Void
    let goHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(back: back)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(title)
                        .ecoFont(.title1)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .ecoFont(.body2)
                        .foregroundStyle(Color.ecoTextSub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenHorizontal)
                .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                VStack(spacing: Spacing.sm) {
                    EcoButton(primaryTitle) {
                        await primaryAction()
                    }
                    EcoButton("홈으로", style: .secondary, action: goHome)
                }
            }
        }
    }
}
