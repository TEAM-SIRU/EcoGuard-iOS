import SwiftUI

/// Figma `03 모집 공고 · 조회 실패` (514:136) 레이아웃. 공고 없음·결과 조회 실패도 같은 레이아웃을 쓴다.
struct RecruitmentMessageView: View {
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
