import Testing
@testable import EcoGuard

@MainActor
struct MainTabViewModelTests {
    @Test func startsOnHome() {
        let viewModel = MainTabViewModel()

        #expect(viewModel.selectedTab == .home)
    }

    @Test(arguments: MainTab.allCases)
    func selectingTabSelectsOnlyThatTab(tab: MainTab) {
        let viewModel = MainTabViewModel()

        viewModel.select(tab)

        #expect(viewModel.selectedTab == tab)
    }

    @Test func selectingAnotherTabThenHomeReturnsHome() {
        let viewModel = MainTabViewModel()

        viewModel.select(.records)
        viewModel.select(.home)

        #expect(viewModel.selectedTab == .home)
    }
}
