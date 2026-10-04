import SwiftUI

/// Figma `06-5 업로드 실패` (514:20) · `06-6 시간 초과` (514:49). 제목·설명과 하단 버튼 두 개.
/// 이의신청 제출 실패 (514:165) · 결과 승인 (514:194)도 같은 구성이다. 승인은 제목 아래 `highlight`(+10분)를 둔다.
struct VerificationMessageView: View {
    let title: LocalizedStringKey
    var highlight: String?
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let primaryAction: () async -> Void
    let back: () -> Void
    var secondaryTitle: LocalizedStringKey = "홈으로"
    let secondaryAction: () -> Void
    /// 첫 버튼 동작이 진행 중이다. 뒤로·두 번째 버튼만 막는다. 첫 버튼은 `EcoButton`이 스스로 로딩으로 보여 준다.
    var isBusy = false

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(back: back)
                .disabled(isBusy)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    Text(title)
                        .ecoFont(.title1)
                        .foregroundStyle(Color.ecoTextPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let highlight {
                        Text(verbatim: highlight)
                            .ecoFont(.display)
                            .foregroundStyle(Color.ecoPrimaryText)
                    }
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
                    EcoButton(secondaryTitle, style: .secondary, action: secondaryAction)
                        .disabled(isBusy)
                }
            }
        }
    }
}
