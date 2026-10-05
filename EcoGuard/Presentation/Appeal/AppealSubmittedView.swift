import SwiftUI

/// Figma `09-2 이의신청 완료` (317:980). 제출 직후에는 뒤로가기 없이 `홈으로`로 닫는다.
/// 검토 중인 이의신청을 다시 열 때도 같은 화면을 쓰고, 그때는 `back`을 넘겨 뒤로가기를 둔다.
struct AppealSubmittedView: View {
    let appeal: Appeal
    var back: (() -> Void)?
    let goHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let back {
                VerificationNavBar(back: back)
            }
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VerificationResultHeader(
                            title: "이의신청을 보냈어요",
                            message: "선생님이 사진과 내용을 보고 결과를 알려드려요",
                            icon: HeroIcon(icon: .iconClockHero, style: .result(tint: .ecoPendingIcon))
                        )
                        .padding(.bottom, Spacing.xxxl)
                        VerificationInfoTable(rows: [
                            .init(
                                label: "대상 인증",
                                value: VerificationResultFormatter.dateTime(appeal.verifiedAt, includesTime: appeal.isVerifiedTimeKnown)
                            ),
                            .init(label: "보낸 시각", value: HomeFormatter.recordDate(appeal.submittedAt))
                        ])
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .safeAreaInset(edge: .bottom) {
            BottomCTA {
                EcoButton("홈으로", style: .secondary, action: goHome)
            }
        }
    }
}

#Preview("제출 직후") {
    AppealSubmittedView(appeal: MockAppealRepository.Fixture.reviewing, goHome: {})
}

#Preview("내역에서 열기") {
    AppealSubmittedView(appeal: MockAppealRepository.Fixture.reviewing, back: {}, goHome: {})
}
