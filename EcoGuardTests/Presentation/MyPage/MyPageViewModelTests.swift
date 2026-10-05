import Testing
@testable import EcoGuard

@MainActor
struct MyPageViewModelTests {
    /// `onLoggedOut` 호출 횟수를 센다.
    private final class LogoutSpy {
        var loggedOutCount = 0
    }

    /// 메모리에만 값을 두는 설정 저장소. 저장한 적이 없으면 켠 상태다.
    private final class InMemoryNotificationSettingRepository: NotificationSettingRepository {
        private var isOn: Bool?

        func isCleaningReminderOn() -> Bool { isOn ?? true }
        func setCleaningReminderOn(_ isOn: Bool) { self.isOn = isOn }
    }

    private func makeViewModel(
        scenarios: [MockMyPageRepository.Scenario] = [.guardian],
        logoutDelay: Duration = .zero,
        logoutFails: Bool = false,
        settings: NotificationSettingRepository? = nil
    ) -> (MyPageViewModel, MockAuthRepository, MockMyPageRepository, LogoutSpy) {
        let authRepository = MockAuthRepository(delay: logoutDelay, logoutFails: logoutFails)
        let myPageRepository = MockMyPageRepository(scenarios: scenarios, delay: .zero)
        let spy = LogoutSpy()
        let container = DIContainer(
            authRepository: authRepository,
            homeRepository: MockHomeRepository(delay: .zero),
            recruitmentRepository: MockRecruitmentRepository(delay: .zero),
            webAdminURL: nil
        )
        let viewModel = container.makeMyPageViewModel(
            repository: myPageRepository,
            notificationSettingRepository: settings ?? InMemoryNotificationSettingRepository(),
            onLoggedOut: { spy.loggedOutCount += 1 }
        )
        return (viewModel, authRepository, myPageRepository, spy)
    }

    @Test func loadShowsSummary() async {
        let (viewModel, _, _, _) = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .loaded(MockMyPageRepository.Fixture.guardian))
    }

    @Test func failedLoadCanBeRetried() async {
        let (viewModel, _, repository, _) = makeViewModel(scenarios: [.failure, .guardian])

        await viewModel.load()
        #expect(viewModel.state == .failed)
        await viewModel.load()

        #expect(repository.fetchCallCount == 2)
        #expect(viewModel.state == .loaded(MockMyPageRepository.Fixture.guardian))
    }

    @Test func cleaningReminderIsOnByDefault() {
        let (viewModel, _, _, _) = makeViewModel()

        #expect(viewModel.isCleaningReminderOn)
    }

    @Test func cleaningReminderChoiceIsKeptForNextVisit() {
        let settings = InMemoryNotificationSettingRepository()
        let (first, _, _, _) = makeViewModel(settings: settings)

        first.setCleaningReminder(false)
        let (second, _, _, _) = makeViewModel(settings: settings)

        #expect(!first.isCleaningReminderOn)
        #expect(!second.isCleaningReminderOn)
        #expect(!settings.isCleaningReminderOn())
    }

    @Test func requestLogoutShowsConfirm() {
        let (viewModel, authRepository, _, _) = makeViewModel()

        viewModel.requestLogout()

        #expect(viewModel.isLogoutConfirmPresented)
        #expect(authRepository.logoutCallCount == 0)
    }

    @Test func cancelClosesConfirmWithoutLoggingOut() {
        let (viewModel, authRepository, _, spy) = makeViewModel()
        viewModel.requestLogout()

        viewModel.cancelLogout()

        #expect(!viewModel.isLogoutConfirmPresented)
        #expect(authRepository.logoutCallCount == 0)
        #expect(spy.loggedOutCount == 0)
    }

    @Test func confirmLogsOutAndCallsCompletionAfterDismiss() async {
        let (viewModel, authRepository, _, spy) = makeViewModel()
        viewModel.requestLogout()

        await viewModel.confirmLogout()

        #expect(authRepository.logoutCallCount == 1)
        #expect(!viewModel.isLogoutConfirmPresented)
        #expect(!viewModel.isLoggingOut)
        #expect(spy.loggedOutCount == 0)

        viewModel.logoutConfirmDidDismiss()

        #expect(spy.loggedOutCount == 1)
    }

    @Test func dismissAfterCancelDoesNotCallCompletion() {
        let (viewModel, _, _, spy) = makeViewModel()
        viewModel.requestLogout()

        viewModel.cancelLogout()
        viewModel.logoutConfirmDidDismiss()

        #expect(spy.loggedOutCount == 0)
    }

    @Test func failedLogoutStillCallsCompletion() async {
        let (viewModel, authRepository, _, spy) = makeViewModel(logoutFails: true)
        viewModel.requestLogout()

        await viewModel.confirmLogout()
        viewModel.logoutConfirmDidDismiss()

        #expect(authRepository.logoutCallCount == 1)
        #expect(spy.loggedOutCount == 1)
        #expect(!viewModel.isLogoutConfirmPresented)
    }

    @Test func confirmWithoutRequestIsIgnored() async {
        let (viewModel, authRepository, _, spy) = makeViewModel()

        await viewModel.confirmLogout()

        #expect(authRepository.logoutCallCount == 0)
        #expect(spy.loggedOutCount == 0)
    }

    @Test func repeatedTapsWhileLoggingOutAreIgnored() async {
        let (viewModel, authRepository, _, spy) = makeViewModel(logoutDelay: .milliseconds(200))
        viewModel.requestLogout()

        let first = Task { await viewModel.confirmLogout() }
        while !viewModel.isLoggingOut {
            await Task.yield()
        }
        await viewModel.confirmLogout()
        viewModel.cancelLogout()
        #expect(viewModel.isLogoutConfirmPresented)
        await first.value
        viewModel.logoutConfirmDidDismiss()
        viewModel.logoutConfirmDidDismiss()

        #expect(authRepository.logoutCallCount == 1)
        #expect(spy.loggedOutCount == 1)
    }

    @Test func requestLogoutAfterLoggingOutDoesNotReopenConfirm() async {
        let (viewModel, _, _, _) = makeViewModel()
        viewModel.requestLogout()
        await viewModel.confirmLogout()

        // 팝업이 내려가는 동안 로그아웃 행을 다시 눌러도 열리지 않는다.
        viewModel.requestLogout()

        #expect(!viewModel.isLogoutConfirmPresented)
    }

    // MARK: - 돌아왔을 때 새로고침

    @Test func refreshReplacesLoadedSummaryWithoutLoading() async {
        let (viewModel, _, repository, _) = makeViewModel(scenarios: [.notApplied, .guardian])
        await viewModel.load()

        await viewModel.refresh()

        #expect(repository.fetchCallCount == 2)
        #expect(viewModel.state == .loaded(MockMyPageRepository.Fixture.guardian))
    }

    @Test func failedRefreshKeepsLoadedSummary() async {
        let (viewModel, _, _, _) = makeViewModel(scenarios: [.guardian, .failure])
        await viewModel.load()

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(MockMyPageRepository.Fixture.guardian))
    }

    @Test func refreshBeforeLoadLoads() async {
        let (viewModel, _, repository, _) = makeViewModel()

        await viewModel.refresh()

        #expect(repository.fetchCallCount == 1)
        #expect(viewModel.state == .loaded(MockMyPageRepository.Fixture.guardian))
    }
}
