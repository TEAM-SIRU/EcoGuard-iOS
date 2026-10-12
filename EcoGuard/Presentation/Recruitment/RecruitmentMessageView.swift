import SwiftUI

/// Figma `03 모집 공고 · 조회 실패` (823:4350) 레이아웃. 공고 없음·결과 조회 실패도 같은 레이아웃을 쓴다.
/// 조회 실패는 빨간 alert, 공고 없음처럼 실패가 아닌 안내는 회색 아이콘을 넘긴다.
struct RecruitmentMessageView: View {
    var icon: ImageResource = .iconAlertHero
    var iconTint: Color = .ecoRejected
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    /// 있으면 primary 버튼(예: 다시 시도)을 홈으로 위에 둔다.
    var retry: (() async -> Void)?
    let onBack: () -> Void
    /// `홈으로`. 흐름을 닫고 홈 탭 첫 화면으로 간다.
    let goHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            EcoNavBar(onBack: onBack)
            ScrollView {
                EcoMessageContent(icon: icon, iconTint: iconTint, title: title, message: message)
                    .containerRelativeFrame(.vertical, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                VStack(spacing: Spacing.sm) {
                    if let retry {
                        EcoButton(RecruitmentCopy.Common.retry) {
                            await retry()
                        }
                    }
                    EcoButton(RecruitmentCopy.Common.home, style: retry == nil ? .primary : .secondary, action: goHome)
                }
            }
        }
        .background(Color.ecoCanvas)
    }
}

#Preview("조회 실패") {
    RecruitmentMessageView(
        title: RecruitmentCopy.Notice.failedTitle,
        message: RecruitmentCopy.Notice.failedMessage,
        retry: {},
        onBack: {},
        goHome: {}
    )
}
