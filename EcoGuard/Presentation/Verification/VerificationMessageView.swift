import SwiftUI

/// Figma `06-5 업로드 실패` (823:4190) · `06-6 시간 초과` (823:4223). 가운데 아이콘·제목·설명과 하단 버튼 두 개.
/// 이의신청 제출 실패 (823:4383) · 결과 승인 (823:4416)도 같은 구성이다. 승인은 제목 아래 `highlight`(+10분)를 둔다.
struct VerificationMessageView: View {
    var icon: ImageResource = .iconAlertHero
    var iconTint: Color = .ecoRejected
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
                EcoMessageContent(icon: icon, iconTint: iconTint, title: title, highlight: highlight, message: message)
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
        .background(Color.ecoCanvas)
    }
}
