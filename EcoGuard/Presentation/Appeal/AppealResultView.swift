import SwiftUI

/// 이의신청 결과. 반려 Figma `09-4 이의신청 결과 · 반려` (317:1177) · 승인 `09-4 이의신청 결과 · 승인` (514:194).
/// 검토 중이면 결과가 나오기 전이라 완료 화면(317:980)을 뒤로가기와 함께 보여 준다.
struct AppealResultView: View {
    let appeal: Appeal
    let back: () -> Void
    /// `다시 이의신청하기`. 같은 인증으로 작성 화면을 연다.
    let appealAgain: (AppealTarget) -> Void
    /// `활동 기록 보기`.
    let showActivity: () -> Void
    let goHome: () -> Void

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
    }

    @ViewBuilder
    private var content: some View {
        switch appeal.status {
        case .reviewing:
            AppealSubmittedView(appeal: appeal, back: back, goHome: goHome)
        case .approved:
            VerificationMessageView(
                title: "이의신청이 승인됐어요",
                highlight: AppealFormatter.earned(appeal),
                message: LocalizedStringKey(approvedMessage),
                primaryTitle: "활동 기록 보기",
                primaryAction: { showActivity() },
                back: back,
                secondaryAction: goHome
            )
        case .rejected:
            AppealRejectedView(
                appeal: appeal,
                back: back,
                appealAgain: { appealAgain(appeal.retryTarget) },
                goHome: goHome
            )
        }
    }

    private var approvedMessage: String {
        "\(AppealFormatter.resultSubtitle(appeal))\n\n선생님이 청소한 내용을 확인했어요.\n활동 기록에 \(appeal.earnedMinutes)분이 추가됐어요."
    }
}

/// 반려 (317:1177). 인증 반려(239:240)와 같은 구성이라 아이콘 영역도 같이 80(위 32)에 그린다.
private struct AppealRejectedView: View {
    let appeal: Appeal
    let back: () -> Void
    let appealAgain: () -> Void
    let goHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VerificationNavBar(back: back)
            ScrollView {
                VStack(spacing: 0) {
                    VerificationResultHeader(
                        title: "이의신청이 반려됐어요",
                        message: AppealFormatter.resultSubtitle(appeal),
                        icon: HeroIcon(icon: .iconAlertHero, style: .result(tint: .ecoRejected))
                    )
                    .padding(.vertical, Spacing.xxxl)
                    if let reply = appeal.teacherReply {
                        VerificationReviewNote(label: "선생님 답변", title: reply.title, guide: reply.message)
                    }
                    // 사진은 선택이라 첨부한 경우에만 첫 사진을 보여 준다.
                    if let photoURL = appeal.photoURLs.first {
                        VerificationResultPhoto(url: photoURL, height: VerificationPhotoView.Height.compact)
                            .padding(.vertical, Spacing.lg)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                VStack(spacing: Spacing.sm) {
                    EcoButton("다시 이의신청하기", action: appealAgain)
                    Text("이의신청은 횟수 제한 없이 할 수 있어요")
                        .ecoFont(.captionRegular)
                        .foregroundStyle(Color.ecoTextCaption)
                        .multilineTextAlignment(.center)
                    EcoButton("홈으로", style: .secondary, action: goHome)
                }
            }
        }
    }
}

private func resultPreview(_ appeal: Appeal) -> some View {
    AppealResultView(appeal: appeal, back: {}, appealAgain: { _ in }, showActivity: {}, goHome: {})
}

#Preview("반려") {
    resultPreview(MockAppealRepository.Fixture.rejected)
}

#Preview("승인") {
    resultPreview(MockAppealRepository.Fixture.approved)
}

#Preview("검토 중") {
    resultPreview(MockAppealRepository.Fixture.reviewing)
}
