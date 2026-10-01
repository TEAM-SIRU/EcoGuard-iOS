import Observation

@Observable
@MainActor
final class MainTabViewModel {
    private(set) var selectedTab: MainTab

    init(selectedTab: MainTab = .home) {
        self.selectedTab = selectedTab
    }

    func select(_ tab: MainTab) {
        selectedTab = tab
    }
}
