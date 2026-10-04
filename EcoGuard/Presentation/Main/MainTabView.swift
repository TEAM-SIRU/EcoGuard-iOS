import SwiftUI

/// 학생 로그인 후 앱 셸. 하단 탭 바(Figma `Tab bar` 255:2)와 가운데 카메라 버튼.
struct MainTabView: View {
    let container: DIContainer
    let homeViewModel: HomeViewModel
    @State private var viewModel = MainTabViewModel()
    /// 홈 위에 전체 화면으로 띄우는 흐름(청소 인증, 모집·신청).
    @State private var presented: PresentedFlow?
    /// 탭을 오가도 도면을 다시 불러오지 않도록 셸이 들고 있는다.
    @State private var cleaningAreaViewModel: CleaningAreaViewModel?
    /// 탭을 오가도 고른 달과 기록을 유지하도록 셸이 들고 있는다.
    @State private var activityRecordsViewModel: ActivityRecordsViewModel?

    @Environment(\.scenePhase) private var scenePhase

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
                guard tab == .home else { return }
                Task { await homeViewModel.refreshIfNeeded(now: .now) }
            }
            // 인증·신청 흐름을 닫으면 홈 상태(인증 결과, 가입 상태)와 활동 기록(오늘 제출분)이 바뀌었을 수 있어 다시 조회한다.
            .fullScreenCover(item: $presented, onDismiss: refreshAfterFlow) { flow in
                flowView(flow)
            }
    }

    @ViewBuilder
    private func flowView(_ flow: PresentedFlow) -> some View {
        switch flow {
        case .camera(let cameraViewModel):
            CameraVerificationView(
                viewModel: cameraViewModel,
                actions: CameraVerificationView.Actions(close: dismissFlow)
            )
        case .recruitment:
            RecruitmentFlowView(container: container, onExit: dismissFlow)
        case .applicationResult(let resultViewModel):
            NavigationStack {
                ApplicationResultView(viewModel: resultViewModel, onExit: dismissFlow)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .home:
            HomeView(
                viewModel: homeViewModel,
                actions: HomeView.Actions(
                    verify: openCamera,
                    openRecords: { viewModel.select(.records) },
                    openRecruitment: { presented = .recruitment },
                    openApplicationResult: { presented = .applicationResult(container.makeApplicationResultViewModel()) }
                )
            )
        case .area:
            if let cleaningAreaViewModel {
                CleaningAreaView(viewModel: cleaningAreaViewModel)
            }
        case .records:
            if let activityRecordsViewModel {
                ActivityRecordsView(
                    viewModel: activityRecordsViewModel,
                    // 카메라 버튼과 같이 활동 중일 때만 빈 기록에서 인증으로 보낸다.
                    actions: ActivityRecordsView.Actions(verify: homeViewModel.isCameraAvailable ? { openCamera() } : nil)
                )
            }
        case .myPage:
            ComingSoonView(title: viewModel.selectedTab.title)
        }
    }

    private func item(_ tab: MainTab) -> EcoTabItem {
        EcoTabItem(id: tab, title: tab.title, icon: tab.icon, isSelected: viewModel.selectedTab == tab) {
            viewModel.select(tab)
        }
    }

    private func openCamera() {
        presented = .camera(container.makeCameraVerificationViewModel())
    }

    private func refreshAfterFlow() {
        Task { await homeViewModel.refresh() }
        guard let activityRecordsViewModel else { return }
        Task { await activityRecordsViewModel.refresh() }
    }

    private func dismissFlow() {
        presented = nil
    }
}

/// 아직 만들지 않은 탭의 임시 화면.
private struct ComingSoonView: View {
    let title: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(title)
                .ecoFont(.title2)
                .foregroundStyle(Color.ecoTextPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("준비 중이에요")
                .ecoFont(.body2)
                .foregroundStyle(Color.ecoTextSub)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ecoSurface)
    }
}

#Preview("활동 중") {
    MainTabView(container: .preview(), homeViewModel: DIContainer.preview(homeScenario: .notSubmitted).makeHomeViewModel())
}

#Preview("모집 기간") {
    MainTabView(container: .preview(), homeViewModel: DIContainer.preview(homeScenario: .recruiting).makeHomeViewModel())
}

/// 셸에서 전체 화면으로 띄우는 흐름. 띄울 때마다 새 ViewModel로 시작한다.
private enum PresentedFlow: Identifiable {
    case camera(CameraVerificationViewModel)
    case recruitment
    case applicationResult(ApplicationResultViewModel)

    var id: String {
        switch self {
        case .camera: "camera"
        case .recruitment: "recruitment"
        case .applicationResult: "applicationResult"
        }
    }
}
