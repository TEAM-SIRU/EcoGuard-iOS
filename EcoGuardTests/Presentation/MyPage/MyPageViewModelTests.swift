import Testing
@testable import EcoGuard

@MainActor
struct MyPageViewModelTests {
    /// `onLoggedOut` 호출 횟수를 센다.
    private final class LogoutSpy {
        var loggedOutCount = 0
    }

    private func makeViewModel(
        scenarios: [MockMyPageRepository.Scenario] = [.guardian],
        logoutDelay: Duration = .zero,
        logoutFails: Bool = false
    ) -> (MyPageViewModel, MockAuthRepository, MockMyPageRepository, LogoutSpy) {
        let authRepository = MockAuthRepository(delay: logoutDelay, logoutFails: logoutFails)
        let myPageRepository = MockMyPageRepository(scenarios: scenarios, delay: .zero)
        let spy = LogoutSpy()
        let viewModel = MyPageViewModel(
            fetchMyPageUseCase: FetchMyPageUseCase(myPageRepository: myPageRepository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
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

    @Test func cleaningReminderStartsOnAndToggles() {
        let (viewModel, _, _, _) = makeViewModel()
        #expect(viewModel.isCleaningReminderOn)

        viewModel.isCleaningReminderOn = false
        #expect(!viewModel.isCleaningReminderOn)

        viewModel.isCleaningReminderOn = true
        #expect(viewModel.isCleaningReminderOn)
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

    @Test func confirmLogsOutAndCallsCompletion() async {
        let (viewModel, authRepository, _, spy) = makeViewModel()
        viewModel.requestLogout()

        await viewModel.confirmLogout()

        #expect(authRepository.logoutCallCount == 1)
        #expect(spy.loggedOutCount == 1)
        #expect(!viewModel.isLogoutConfirmPresented)
        #expect(!viewModel.isLoggingOut)
    }

    @Test func failedLogoutStillCallsCompletion() async {
        let (viewModel, authRepository, _, spy) = makeViewModel(logoutFails: true)
        viewModel.requestLogout()

        await viewModel.confirmLogout()

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
        viewModel.requestLogout()
        #expect(viewModel.isLogoutConfirmPresented)
        await first.value

        #expect(authRepository.logoutCallCount == 1)
        #expect(spy.loggedOutCount == 1)
        #expect(!viewModel.isLogoutConfirmPresented)
    }
}
