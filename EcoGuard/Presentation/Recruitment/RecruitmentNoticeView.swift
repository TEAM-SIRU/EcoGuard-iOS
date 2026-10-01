import SwiftUI

/// Figma `03 모집 공고` (246:3) · `마감` (313:2) · `이미 신청` (313:53) · `조회 실패` (514:136).
/// 신청 기간 아님·공고 없음은 Figma에 프레임이 없어 같은 레이아웃에 문구만 새로 썼다(문구는 `RecruitmentCopy`).
/// 모집 흐름의 첫 화면이라 Figma 246:3에 없는 뒤로가기(나가기) 버튼을 위에 둔다.
struct RecruitmentNoticeView: View {
    let viewModel: RecruitmentNoticeViewModel
    let onApply: (Applicant, Int) -> Void
    let onExit: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if viewModel.state == .loading {
                    await viewModel.load()
                }
            }
            // 신청 시작·마감 시각이 되면 서버 상태가 바뀌므로 다시 조회한다. 이미 지난 시각이면 바로 조회한다.
            .task(id: viewModel.nextRefreshDate) {
                guard let date = viewModel.nextRefreshDate else { return }
                let remaining = date.timeIntervalSinceNow
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }
                }
                await viewModel.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await viewModel.refresh() }
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
                title: RecruitmentCopy.Notice.emptyTitle,
                message: RecruitmentCopy.Notice.emptyMessage,
                onBack: onExit,
                onExit: onExit
            )
        case .failed:
            RecruitmentMessageView(
                title: RecruitmentCopy.Notice.failedTitle,
                message: RecruitmentCopy.Notice.failedMessage,
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
        .accessibilityLabel(Text(RecruitmentCopy.Common.loading))
    }

    private func loadedView(detail: RecruitmentDetail, applicant: Applicant) -> some View {
        let recruitment = detail.recruitment
        let status = detail.status
        return VStack(spacing: 0) {
            EcoNavBar(onBack: onExit)
            ScrollView {
                VStack(spacing: 0) {
                    EcoPageHeader(
                        title: RecruitmentCopy.Notice.title(semester: recruitment.semester),
                        subtitle: RecruitmentCopy.Notice.subtitle(capacity: recruitment.capacityPerClass)
                    )
                    .padding(.top, Spacing.lg)
                    EcoInfoTable(rows: [
                        .init(label: RecruitmentCopy.Notice.periodLabel, value: RecruitmentFormatter.period(start: detail.startDate, end: detail.endDate)),
                        .init(label: RecruitmentCopy.Notice.capacityLabel, value: RecruitmentCopy.Notice.capacityValue(recruitment.capacityPerClass)),
                        .init(label: RecruitmentCopy.Notice.activityLabel, value: RecruitmentFormatter.activityTime(detail.activityWindow))
                    ])
                    .padding(.horizontal, Spacing.screenHorizontal)
                    EcoProgressSummary(
                        title: RecruitmentCopy.Notice.progressTitle(className: recruitment.className),
                        value: RecruitmentCopy.Notice.progressValue(applied: recruitment.appliedCount, capacity: recruitment.capacityPerClass),
                        valueAccessibilityLabel: RecruitmentCopy.Notice.progressAccessibility(
                            applied: recruitment.appliedCount,
                            capacity: recruitment.capacityPerClass
                        ),
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
                        title: RecruitmentCopy.Notice.benefitTitle,
                        subtitle: RecruitmentCopy.Notice.benefitSubtitle,
                        horizontalPadding: Spacing.screenHorizontal
                    )
                    EcoListRow(
                        icon: nil,
                        title: RecruitmentCopy.Notice.howTitle,
                        subtitle: RecruitmentCopy.Notice.howSubtitle,
                        horizontalPadding: Spacing.screenHorizontal
                    )
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let button = buttonTitle(for: status) {
                BottomCTA {
                    // 마감 시각이 지나면 다시 조회되기 전이라도 버튼을 끈다.
                    TimelineView(.explicit([detail.endDate])) { context in
                        EcoButton(button) {
                            onApply(applicant, recruitment.capacityPerClass)
                        }
                        .disabled(!viewModel.canApply(at: context.date))
                    }
                }
                .background(Color.ecoCard)
            }
        }
    }

    private func caption(for status: RecruitmentStatus, detail: RecruitmentDetail) -> String {
        switch status {
        case .open:
            RecruitmentCopy.Notice.openCaption(remainingSeats: detail.remainingSeats)
        case .full:
            RecruitmentCopy.Notice.fullCaption(className: detail.recruitment.className)
        case .applied(let application):
            RecruitmentCopy.Notice.appliedCaption(appliedAt: RecruitmentFormatter.appliedAt(application.appliedAt), order: application.order)
        case .upcoming:
            RecruitmentCopy.Notice.upcomingCaption(startDay: RecruitmentFormatter.day(detail.startDate))
        case .ended:
            RecruitmentCopy.Notice.endedCaption
        }
    }

    /// 이미 신청했으면 버튼을 두지 않는다(Figma 313:53).
    private func buttonTitle(for status: RecruitmentStatus) -> LocalizedStringKey? {
        switch status {
        case .open: RecruitmentCopy.Notice.apply
        case .full, .ended: RecruitmentCopy.Notice.closed
        case .upcoming: RecruitmentCopy.Notice.notInPeriod
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
