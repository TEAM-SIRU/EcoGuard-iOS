import SwiftUI

/// Figma `03 모집 공고 · 조회 실패` (514:136) 레이아웃. 공고 없음·결과 조회 실패도 같은 레이아웃을 쓴다.
struct RecruitmentMessageView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    /// 있으면 primary 버튼(예: 다시 시도)을 홈으로 위에 둔다.
    var retry: (() async -> Void)?
    let onBack: () -> Void
    let onExit: () -> Void

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
                        EcoButton("다시 시도") {
                            await retry()
                        }
                    }
                    EcoButton("홈으로", style: retry == nil ? .primary : .secondary, action: onExit)
                }
            }
        }
    }
}

#Preview("조회 실패") {
    RecruitmentMessageView(
        title: "모집 공고를 불러오지 못했어요",
        message: "모집 상태를 확인하지 못했어요.\n다시 불러온 뒤 신청 가능 여부를 확인해 주세요.",
        retry: {},
        onBack: {},
        onExit: {}
    )
}
