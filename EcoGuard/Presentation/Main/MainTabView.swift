import SwiftUI

/// 학생 로그인 후 앱 셸. 하단 탭 바(Figma `Tab bar` 255:2)와 가운데 카메라 버튼.
struct MainTabView: View {
    let homeViewModel: HomeViewModel
    @State private var viewModel = MainTabViewModel()

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
                        .disabled(!homeViewModel.isCameraAvailable)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.selectedTab {
        case .home:
            HomeView(
                viewModel: homeViewModel,
                actions: HomeView.Actions(verify: openCamera, openRecords: { viewModel.select(.records) })
            )
        case .area, .records, .myPage:
            ComingSoonView(title: viewModel.selectedTab.title)
        }
    }

    private func item(_ tab: MainTab) -> EcoTabItem {
        EcoTabItem(id: tab, title: tab.title, icon: tab.icon, isSelected: viewModel.selectedTab == tab) {
            viewModel.select(tab)
        }
    }

    // TODO: 청소 인증(카메라) 화면 이슈에서 연결
    private func openCamera() {}
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
    MainTabView(homeViewModel: DIContainer.preview(homeScenario: .notSubmitted).makeHomeViewModel())
}

#Preview("모집 기간") {
    MainTabView(homeViewModel: DIContainer.preview(homeScenario: .recruiting).makeHomeViewModel())
}
