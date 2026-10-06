import SwiftUI

/// Figma `02 홈` 상태별 화면 11개.
/// 하단 탭 바·카메라 FAB는 앱 셸(`MainTabView`)이 붙이고, 카메라 버튼만큼의 스크롤 끝 여백도 셸이 더한다.
struct HomeView: View {
    /// 다른 화면으로 가는 동작. 앱 셸(`MainTabView`)이 모두 연결하고, 기본값(아무것도 안 함)은 Preview용이다.
    struct Actions {
        var verify: () -> Void = {}
        var openNotices: () -> Void = {}
        var openNotice: (Notice) -> Void = { _ in }
        var openRecords: () -> Void = {}
        var openSubmittedPhoto: () -> Void = {}
        var appeal: () -> Void = {}
        var openRecruitment: () -> Void = {}
        var openApplicationResult: () -> Void = {}
    }

    let viewModel: HomeViewModel
    var actions = Actions()

    /// 인증 시작·마감 시각과 앱 복귀 재조회는 다른 탭에 있어도 돌도록 셸(`MainTabView`)이 맡는다.
    var body: some View {
        content
            .task {
                // 처음 들어올 때, 그리고 불러오던 중 화면을 떠났다 돌아왔을 때 불러온다.
                guard !isLoaded else { return }
                await viewModel.load()
            }
    }

    private var isLoaded: Bool {
        if case .loaded = viewModel.state { true } else { false }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            HomeLoadingView()
        case .failed:
            HomeMessageView(
                title: "홈을 불러오지 못했어요",
                message: "네트워크 연결을 확인한 뒤 다시 시도해 주세요.",
                primaryTitle: "다시 시도",
                primaryAction: { await viewModel.retry() },
                secondaryAction: actions.openNotices
            )
        case .loaded(let summary):
            if case .excluded(let reason) = summary.status {
                HomeMessageView(
                    title: "환경지킴이 활동이 취소됐어요",
                    message: "담당 선생님이 활동에서 제외했어요.\n\n제외 사유\n\(reason)\n\n사유에 대해 궁금하면 담당 선생님께 문의해 주세요.",
                    primaryTitle: "홈으로",
                    // 이미 홈 탭 첫 화면이라 옮길 곳이 없다. 활동 상태를 다시 확인해 제외가 풀렸으면 홈을 보여 준다.
                    primaryAction: { await viewModel.load() },
                    secondaryAction: actions.openNotices
                )
            } else {
                loaded(summary)
            }
        }
    }

    private func loaded(_ summary: HomeSummary) -> some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: Spacing.md) {
                    if let notice = summary.notice {
                        HomeNoticeCard(
                            notice: notice,
                            onOpen: { actions.openNotice(notice) },
                            onDismiss: { Task { await viewModel.dismissNotice() } }
                        )
                    }
                    statusContent(summary.status)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxxl)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .background(Color.ecoSurface)
    }

    private var topBar: some View {
        HStack {
            Text("환경지킴이")
                .ecoFont(.title3)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            EcoIconButton(icon: .iconBell, color: .ecoTextPrimary, accessibilityLabel: "공지", action: actions.openNotices)
        }
        .padding(.horizontal, Spacing.screenHorizontal)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func statusContent(_ status: HomeStatus) -> some View {
        switch status {
        case .recruiting(let recruitment):
            HomeRecruitCard(content: .recruiting(recruitment), action: actions.openRecruitment)
        case .awaitingAssignment:
            HomeRecruitCard(content: .awaitingAssignment, action: actions.openApplicationResult)
        case .notSelected:
            HomeRecruitCard(content: .notSelected)
        case .notRecruiting:
            HomeRecruitCard(content: .notRecruiting)
        case .excluded:
            EmptyView()
        case .active(let cleaning):
            HomeTodayCard(today: cleaning.today, canVerify: viewModel.canVerify(at:), actions: actions)
            HomeWeekCard(week: cleaning.week)
            HomeRecentRecordsSection(records: cleaning.recentRecords, onOpenAll: actions.openRecords)
        }
    }
}

#Preview("미제출") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .notSubmitted).makeHomeViewModel())
}

#Preview("검수 중") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .aiReviewing).makeHomeViewModel())
}

#Preview("승인") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .approved).makeHomeViewModel())
}

#Preview("반려") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .rejected).makeHomeViewModel())
}

#Preview("선생님 확인 중") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .teacherReviewing).makeHomeViewModel())
}

#Preview("인증 시간 아님") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .notOpenYet).makeHomeViewModel())
}

#Preview("모집 기간 (미가입)") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .recruiting).makeHomeViewModel())
}

#Preview("구역 배정 대기") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .awaitingAssignment).makeHomeViewModel())
}

#Preview("미선발") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .notSelected).makeHomeViewModel())
}

#Preview("모집 없음") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .notRecruiting).makeHomeViewModel())
}

#Preview("활동 제외 안내") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .excluded).makeHomeViewModel())
}

#Preview("로딩") {
    HomeView(viewModel: DIContainer(
        authRepository: MockAuthRepository(),
        homeRepository: MockHomeRepository(delay: .seconds(3600)),
        recruitmentRepository: MockRecruitmentRepository(),
        webAdminURL: nil
    ).makeHomeViewModel())
}

#Preview("조회 실패") {
    HomeView(viewModel: DIContainer.preview(homeScenario: .failure).makeHomeViewModel())
}
