import SwiftUI

/// Figma `03 모집 공고` (246:3) · `마감` (313:2) · `이미 신청` (313:53) · `조회 실패` (514:136).
/// 신청 기간 아님·공고 없음은 Figma에 프레임이 없어 같은 레이아웃에 문구만 새로 썼다.
/// 모집 흐름의 첫 화면이라 Figma 246:3에 없는 뒤로가기(나가기) 버튼을 위에 둔다.
struct RecruitmentNoticeView: View {
    let viewModel: RecruitmentNoticeViewModel
    let onApply: (Applicant, Int) -> Void
    let onExit: () -> Void

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.state == .loading {
                    await viewModel.load()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            loadingView
        case .loaded(let detail, let applicant):
            loadedView(detail: detail, applicant: applicant)
        case .empty:
            RecruitmentMessageView(
                title: "지금은 모집 공고가 없어요",
                message: "모집이 시작되면 홈에서 알려드려요.",
                onBack: onExit,
                onExit: onExit
            )
        case .failed:
            RecruitmentMessageView(
                title: "모집 공고를 불러오지 못했어요",
                message: "모집 상태를 확인하지 못했어요.\n다시 불러온 뒤 신청 가능 여부를 확인해 주세요.",
                retry: { await viewModel.retry() },
                onBack: onExit,
                onExit: onExit
            )
        }
    }

    private var loadingView: some View {
        VStack(spacing: 0) {
            EcoNavBar(onBack: onExit)
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                EcoSkeleton(kind: .longLine)
                EcoSkeleton(kind: .card)
                EcoSkeleton(kind: .row)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.screenHorizontal)
            .padding(.top, Spacing.lg)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("불러오는 중이에요"))
    }

    private func loadedView(detail: RecruitmentDetail, applicant: Applicant) -> some View {
        let recruitment = detail.recruitment
        let status = detail.status
        return VStack(spacing: 0) {
            EcoNavBar(onBack: onExit)
            ScrollView {
                VStack(spacing: 0) {
                    EcoPageHeader(
                        title: "\(recruitment.semester)학기 환경지킴이를 모집해요",
                        subtitle: "반마다 최대 \(recruitment.capacityPerClass)명, 먼저 신청한 순서대로 확정돼요"
                    )
                    .padding(.top, Spacing.lg)
                    EcoInfoTable(rows: [
                        .init(label: "모집 기간", value: RecruitmentFormatter.period(start: detail.startDate, end: detail.endDate)),
                        .init(label: "모집 인원", value: "반별 최대 \(recruitment.capacityPerClass)명"),
                        .init(label: "활동 시간", value: RecruitmentFormatter.activityTime(detail.activityWindow))
                    ])
                    .padding(.horizontal, Spacing.screenHorizontal)
                    EcoProgressSummary(
                        title: "\(recruitment.className) 신청 현황",
                        value: "\(recruitment.appliedCount)/\(recruitment.capacityPerClass)명",
                        valueAccessibilityLabel: "\(recruitment.capacityPerClass)명 중 \(recruitment.appliedCount)명 신청",
                        progress: Double(recruitment.appliedCount) / Double(max(recruitment.capacityPerClass, 1)),
                        caption: caption(for: status, detail: detail),
                        isActive: status.isActive
                    )
                    .padding(Spacing.xxl)
                    Rectangle()
                        .fill(Color.ecoDivider)
                        .frame(height: Spacing.md)
                        .accessibilityHidden(true)
                    EcoListRow(
                        icon: nil,
                        title: "인증 1번에 봉사시간 10분",
                        subtitle: "인증이 승인되면 활동 기록에 쌓여요",
                        horizontalPadding: Spacing.screenHorizontal
                    )
                    EcoListRow(
                        icon: nil,
                        title: "사진 1장으로 간단하게 인증",
                        subtitle: "청소를 마치고 카메라로 찍어 보내요",
                        horizontalPadding: Spacing.screenHorizontal
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let button = buttonTitle(for: status) {
                BottomCTA {
                    EcoButton(button) {
                        onApply(applicant, recruitment.capacityPerClass)
                    }
                    .disabled(status != .open)
                }
                .background(Color.ecoCard)
            }
        }
    }

    private func caption(for status: RecruitmentStatus, detail: RecruitmentDetail) -> String {
        switch status {
        case .open:
            "\(detail.remainingSeats)자리 남았어요. 자리가 차면 바로 마감돼요"
        case .full:
            "\(detail.recruitment.className)은 자리가 모두 찼어요. 다음 모집을 기다려 주세요"
        case .applied(let application):
            "\(RecruitmentFormatter.appliedAt(application.appliedAt))에 \(application.order)번째로 신청했어요"
        case .upcoming:
            "\(RecruitmentFormatter.day(detail.startDate))부터 신청할 수 있어요"
        case .ended:
            "신청 기간이 끝났어요. 다음 모집을 기다려 주세요"
        }
    }

    /// 이미 신청했으면 버튼을 두지 않는다(Figma 313:53).
    private func buttonTitle(for status: RecruitmentStatus) -> LocalizedStringKey? {
        switch status {
        case .open: "신청하기"
        case .full, .ended: "모집이 마감됐어요"
        case .upcoming: "신청 기간이 아니에요"
        case .applied: nil
        }
    }
}

private extension RecruitmentStatus {
    /// 진행 막대를 초록으로 둘지. 마감·기간 아님은 회색이다.
    var isActive: Bool {
        switch self {
        case .open, .applied: true
        case .full, .upcoming, .ended: false
        }
    }
}

#Preview("모집 중") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .open).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("마감") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .full).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("이미 신청") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .applied).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("신청 기간 전") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .upcoming).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("신청 기간 끝") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .ended).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("공고 없음") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .none).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("조회 실패") {
    RecruitmentNoticeView(viewModel: DIContainer.preview(recruitmentScenario: .failure).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}

#Preview("로딩") {
    RecruitmentNoticeView(viewModel: DIContainer(
        authRepository: MockAuthRepository(),
        homeRepository: MockHomeRepository(),
        recruitmentRepository: MockRecruitmentRepository(delay: .seconds(3600)),
        webAdminURL: nil
    ).makeRecruitmentNoticeViewModel(), onApply: { _, _ in }, onExit: {})
}
