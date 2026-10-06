import SwiftUI

/// 학생 로그인 후 앱 셸. 하단 탭 바(Figma `Tab bar` 255:2)와 가운데 카메라 버튼.
/// 화면 이동 상태(탭, 전체 탭 경로, 띄운 흐름)는 `MainTabViewModel`이 들고 있다.
struct MainTabView: View {
    let container: DIContainer
    let homeViewModel: HomeViewModel
    /// 마이페이지에서 로그아웃을 마쳤을 때. 앱 셸 밖(`RootView`)에서 로그인 화면으로 돌린다.
    let onLoggedOut: () -> Void
    @State private var viewModel = MainTabViewModel()
    /// 탭을 오가도 도면을 다시 불러오지 않도록 셸이 들고 있는다.
    @State private var cleaningAreaViewModel: CleaningAreaViewModel?
    /// 탭을 오가도 고른 달과 기록을 유지하도록 셸이 들고 있는다.
    @State private var activityRecordsViewModel: ActivityRecordsViewModel?
    /// 전체 탭을 처음 열 때 만든다. 로그인마다 셸이 새로 만들어져 이전 계정 정보가 남지 않는다.
    @State private var myPageViewModel: MyPageViewModel?
    /// 홈 탭에서 push한 공지 화면의 ViewModel. 경로에서 빠지면 놓는다.
    @State private var homeNoticeViewModel: NoticeViewModel?
    /// 전체 탭에서 push한 화면의 ViewModel. 경로에서 빠지면 놓는다.
    @State private var noticeViewModel: NoticeViewModel?
    @State private var appealHistoryViewModel: AppealHistoryViewModel?

    /// 오늘 제출한 인증을 찾지 못했다는 토스트.
    @State private var isShowingSubmissionToast = false

    @Environment(\.scenePhase) private var scenePhase

    private static let submissionUnavailableMessage: LocalizedStringResource = "제출한 인증을 불러오지 못했어요. 잠시 후 다시 확인해 주세요"

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                EcoTabBar(
                    leadingItems: [item(.home), item(.area)],
                    trailingItems: [item(.records), item(.myPage)]
                ) {
                    EcoCameraButton(action: openCamera)
                        // 구역을 배정받아 활동 중일 때만 인증할 수 있다 (Figma 모집 기간·배정 대기 프레임은 회색).
                        // 인증 시간이 아니거나 이미 제출한 날도 켠다. Figma `06 인증 불가` 화면에서 카메라 화면이 서버 상태로 막는다.
                        .disabled(!homeViewModel.isCameraAvailable)
                        .accessibilityHint(homeViewModel.isCameraAvailable ? Text(verbatim: "") : Text("환경지킴이로 활동 중일 때 쓸 수 있어요"))
                }
            }
            // 홈 재조회는 다른 탭에 있어도 돌아야 해서 셸에 둔다. 시각이 이미 지났으면 바로 다시 조회한다.
            .task(id: homeViewModel.nextRefreshDate) {
                guard let date = homeViewModel.nextRefreshDate else { return }
                if date > .now {
                    try? await Task.sleep(for: .seconds(date.timeIntervalSinceNow))
                }
                guard !Task.isCancelled else { return }
                await homeViewModel.refresh()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await homeViewModel.refresh() }
                if let activityRecordsViewModel {
                    Task { await activityRecordsViewModel.refreshOnReturn() }
                }
                if let myPageViewModel {
                    Task { await myPageViewModel.refresh() }
                }
            }
            .onChange(of: viewModel.selectedTab) { _, tab in
                // 구역 탭을 처음 열 때 한 번 만든다. 탭을 오가도 다시 불러오지 않는다.
                if tab == .area, cleaningAreaViewModel == nil {
                    cleaningAreaViewModel = container.makeCleaningAreaViewModel()
                }
                if tab == .records {
                    // 처음 열 때 한 번 만들고, 이후 탭에 돌아올 때마다 새로고침한다(달이 바뀌었으면 이번 달로).
                    if let activityRecordsViewModel {
                        Task { await activityRecordsViewModel.refreshOnReturn() }
                    } else {
                        activityRecordsViewModel = container.makeActivityRecordsViewModel()
                    }
                }
                if tab == .myPage {
                    // 처음 열 때 한 번 만들고, 이후 탭에 돌아올 때마다 이번 달 승인·신청 결과를 다시 조회한다.
                    if let myPageViewModel {
                        Task { await myPageViewModel.refresh() }
                    } else {
                        myPageViewModel = container.makeMyPageViewModel(onLoggedOut: onLoggedOut)
                    }
                }
                guard tab == .home else { return }
                Task { await homeViewModel.refreshIfNeeded(now: .now) }
            }
            .onChange(of: viewModel.homePath) { _, path in
                if path.isEmpty {
                    homeNoticeViewModel = nil
                }
            }
            .onChange(of: viewModel.myPagePath) { _, path in
                if !path.contains(.notices) {
                    noticeViewModel = nil
                }
                if !path.contains(.appealHistory) {
                    appealHistoryViewModel = nil
                }
            }
            // Figma 정의가 없어 다른 실패 토스트와 같은 모양으로 위쪽에 띄운다.
            .overlay(alignment: .top) {
                if isShowingSubmissionToast {
                    EcoToast(message: Self.submissionUnavailableMessage)
                        .padding(.top, Spacing.sm)
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .transition(.opacity)
                }
            }
            .animation(.default, value: isShowingSubmissionToast)
            .task(id: viewModel.submissionUnavailableCount) {
                guard viewModel.submissionUnavailableCount > 0 else { return }
                AccessibilityNotification.Announcement(String(localized: Self.submissionUnavailableMessage)).post()
                isShowingSubmissionToast = true
                guard (try? await Task.sleep(for: EcoToast.displayDuration)) != nil else { return }
                isShowingSubmissionToast = false
            }
            // 흐름을 닫으면 홈 상태(인증 결과, 가입 상태), 활동 기록(오늘 제출분), 마이페이지(이번 달 승인·신청 결과),
            // 이의신청 내역(새로 보낸 이의신청)이 바뀌었을 수 있어 다시 조회한다.
            .fullScreenCover(item: presentedFlowBinding, onDismiss: refreshAfterFlow) { flow in
                flowView(flow)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .home:
            homeStack
        case .area:
            if let cleaningAreaViewModel {
                CleaningAreaView(viewModel: cleaningAreaViewModel)
            }
        case .records:
            if let activityRecordsViewModel {
                ActivityRecordsView(
                    viewModel: activityRecordsViewModel,
                    actions: ActivityRecordsView.Actions(
                        // 카메라 버튼과 같이 활동 중일 때만 빈 기록에서 인증으로 보낸다.
                        verify: homeViewModel.isCameraAvailable ? { openCamera() } : nil,
                        openRecord: { record in viewModel.openRecord(record) }
                    )
                )
            }
        case .myPage:
            if let myPageViewModel {
                myPageStack(myPageViewModel)
            }
        }
    }

    /// 홈 탭. 공지는 탭 바를 둔 채 이 안에서 push해 뒤로 가면 홈으로 돌아온다.
    private var homeStack: some View {
        NavigationStack(path: $viewModel.homePath) {
            HomeView(
                viewModel: homeViewModel,
                actions: HomeView.Actions(
                    verify: openCamera,
                    openNotices: { openHomeNotices(focusing: nil) },
                    openNotice: { notice in openHomeNotices(focusing: notice) },
                    openRecords: { viewModel.select(.records) },
                    openSubmittedPhoto: {
                        guard let submission = homeViewModel.todaySubmission else { return }
                        viewModel.present(.verificationResult(id: submission.id, entry: .history))
                    },
                    appeal: {
                        guard let target = homeViewModel.todayAppealTarget else { return }
                        viewModel.present(.appealForm(target))
                    },
                    openRecruitment: { viewModel.present(.recruitment) },
                    openApplicationResult: openApplicationResult
                )
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MainTabViewModel.HomeRoute.self) { route in
                switch route {
                case .notices(let focusedNoticeID):
                    if let homeNoticeViewModel {
                        NoticeView(viewModel: homeNoticeViewModel, focusedNoticeID: focusedNoticeID, onBack: { viewModel.popHome() })
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden()
                    }
                }
            }
        }
    }

    /// 전체 탭. 공지·이의신청 내역은 탭 바를 둔 채 이 안에서 push한다.
    private func myPageStack(_ myPageViewModel: MyPageViewModel) -> some View {
        NavigationStack(path: $viewModel.myPagePath) {
            MyPageView(
                viewModel: myPageViewModel,
                actions: MyPageView.Actions(
                    openCleaningArea: { viewModel.select(.area) },
                    openApplicationResult: openApplicationResult,
                    openAppeals: {
                        appealHistoryViewModel = container.makeAppealHistoryViewModel()
                        viewModel.push(.appealHistory)
                    },
                    openNotices: {
                        noticeViewModel = container.makeNoticeViewModel()
                        viewModel.push(.notices)
                    }
                )
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MainTabViewModel.MyPageRoute.self) { route in
                myPageDestination(route)
            }
        }
    }

    @ViewBuilder
    private func myPageDestination(_ route: MainTabViewModel.MyPageRoute) -> some View {
        switch route {
        case .notices:
            if let noticeViewModel {
                NoticeView(viewModel: noticeViewModel, onBack: { viewModel.popMyPage() })
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden()
            }
        case .appealHistory:
            if let appealHistoryViewModel {
                AppealHistoryView(
                    viewModel: appealHistoryViewModel,
                    back: { viewModel.popMyPage() },
                    openResult: { appeal in viewModel.present(.appealResult(appeal)) }
                )
            }
        }
    }

    @ViewBuilder
    private func flowView(_ flow: MainTabViewModel.Flow) -> some View {
        switch flow {
        case .camera(let cameraViewModel):
            CameraVerificationView(
                viewModel: cameraViewModel,
                actions: CameraVerificationView.Actions(
                    close: { viewModel.dismissFlow() },
                    openSubmitted: {
                        // 홈이 오늘 제출분을 아직 받지 못했으면(다른 기기에서 제출 등) 다시 조회한 뒤 연다.
                        // 그래도 없으면 이 기기에서 방금 낸 인증 ID로 연다(`verificationSubmitted`).
                        Task {
                            if homeViewModel.todaySubmission == nil {
                                await homeViewModel.refresh()
                            }
                            viewModel.openTodaySubmission(homeViewModel.todaySubmission)
                        }
                    }
                )
            )
            .onChange(of: cameraViewModel.submission) { _, submission in
                if let submission {
                    viewModel.verificationSubmitted(submission)
                }
            }
        case .recruitment:
            RecruitmentFlowView(container: container, onExit: { viewModel.dismissFlow() })
        case .applicationResult(let resultViewModel):
            NavigationStack {
                ApplicationResultView(viewModel: resultViewModel, onExit: { viewModel.dismissFlow() })
            }
        case .verificationResult(let id, let entry):
            flowStack {
                VerificationResultView(
                    viewModel: container.makeVerificationResultViewModel(resultID: id),
                    entry: entry,
                    close: { viewModel.dismissFlow() },
                    goHome: { viewModel.dismissFlow(selecting: .home) },
                    appeal: { result in viewModel.pushInFlow(.appealForm(AppealTarget(result: result))) }
                )
            }
        case .appealForm(let target):
            flowStack {
                appealForm(target)
            }
        case .appealResult(let appeal):
            flowStack {
                AppealResultView(
                    appeal: appeal,
                    back: { viewModel.dismissFlow() },
                    appealAgain: { target in viewModel.pushInFlow(.appealForm(target)) },
                    showActivity: { viewModel.dismissFlow(selecting: .records) },
                    goHome: { viewModel.dismissFlow(selecting: .home) }
                )
            }
        }
    }

    /// 인증 결과·이의신청 흐름. 작성·완료 화면을 이 안에서 push한다.
    private func flowStack(@ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: $viewModel.flowPath) {
            root()
                .navigationDestination(for: MainTabViewModel.FlowRoute.self) { route in
                    switch route {
                    case .appealForm(let target):
                        appealForm(target)
                    case .appealSubmitted(let appeal):
                        AppealSubmittedView(appeal: appeal, goHome: { viewModel.dismissFlow(selecting: .home) })
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden()
                    }
                }
        }
    }

    private func appealForm(_ target: AppealTarget) -> some View {
        AppealFormView(
            viewModel: container.makeAppealFormViewModel(target: target),
            back: { viewModel.backInFlow() },
            makePhotoCapture: { container.makeAppealPhotoCaptureViewModel() },
            onSubmitted: { appeal in viewModel.appealSubmitted(appeal) }
        )
    }

    private var presentedFlowBinding: Binding<MainTabViewModel.Flow?> {
        Binding(
            get: { viewModel.presentedFlow },
            set: { flow in
                if flow == nil { viewModel.dismissFlow() }
            }
        )
    }

    private func item(_ tab: MainTab) -> EcoTabItem {
        EcoTabItem(id: tab, title: tab.title, icon: tab.icon, isSelected: viewModel.selectedTab == tab) {
            viewModel.select(tab)
        }
    }

    private func openCamera() {
        viewModel.present(.camera(container.makeCameraVerificationViewModel()))
    }

    private func openHomeNotices(focusing notice: Notice?) {
        if viewModel.homePath.isEmpty {
            homeNoticeViewModel = container.makeNoticeViewModel()
        }
        viewModel.openNotices(focusing: notice)
    }

    private func openApplicationResult() {
        viewModel.present(.applicationResult(container.makeApplicationResultViewModel()))
    }

    private func refreshAfterFlow() {
        Task { await homeViewModel.refresh() }
        if let activityRecordsViewModel {
            Task { await activityRecordsViewModel.refresh() }
        }
        if let myPageViewModel {
            Task { await myPageViewModel.refresh() }
        }
        if let appealHistoryViewModel {
            Task { await appealHistoryViewModel.refresh() }
        }
    }
}

#Preview("활동 중") {
    MainTabView(
        container: .preview(),
        homeViewModel: DIContainer.preview(homeScenario: .notSubmitted).makeHomeViewModel(),
        onLoggedOut: {}
    )
}

#Preview("모집 기간") {
    MainTabView(
        container: .preview(),
        homeViewModel: DIContainer.preview(homeScenario: .recruiting).makeHomeViewModel(),
        onLoggedOut: {}
    )
}
