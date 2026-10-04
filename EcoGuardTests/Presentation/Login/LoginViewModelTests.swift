import Testing
@testable import EcoGuard

@MainActor
struct LoginViewModelTests {
    private func makeViewModel(
        outcome: MockAuthRepository.Outcome,
        delay: Duration = .zero
    ) -> (LoginViewModel, MockAuthRepository) {
        makeViewModel(outcomes: [outcome], delay: delay)
    }

    private func makeViewModel(
        outcomes: [MockAuthRepository.Outcome],
        delay: Duration = .zero,
        logoutFails: Bool = false
    ) -> (LoginViewModel, MockAuthRepository) {
        let repository = MockAuthRepository(outcomes: outcomes, delay: delay, logoutFails: logoutFails)
        let viewModel = LoginViewModel(
            loginUseCase: LoginUseCase(authRepository: repository),
            logoutUseCase: LogoutUseCase(authRepository: repository)
        )
        return (viewModel, repository)
    }

    @Test func studentLoginMovesToLoggedIn() async {
        let (viewModel, _) = makeViewModel(outcome: .student)

        await viewModel.login()

        #expect(viewModel.state == .loggedIn)
    }

    @Test func teacherLoginMovesToTeacher() async {
        let (viewModel, _) = makeViewModel(outcome: .teacher)

        await viewModel.login()

        #expect(viewModel.state == .teacher)
    }

    @Test func failedLoginMovesToFailed() async {
        let (viewModel, _) = makeViewModel(outcome: .failure)

        await viewModel.login()

        #expect(viewModel.state == .failed)
    }

    @Test func retryAfterFailureCallsLoginAgain() async {
        let (viewModel, repository) = makeViewModel(outcome: .failure)

        await viewModel.login()
        await viewModel.login()

        #expect(repository.loginCallCount == 2)
        #expect(viewModel.state == .failed)
    }

    @Test func loginWhileLoadingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(outcome: .student, delay: .milliseconds(200))

        let firstLogin = Task { await viewModel.login() }
        while viewModel.state != .loading {
            await Task.yield()
        }
        await viewModel.login()

        #expect(viewModel.state == .loading)
        await firstLogin.value
        #expect(repository.loginCallCount == 1)
        #expect(viewModel.state == .loggedIn)
    }

    @Test func logoutFromTeacherReturnsToIdle() async {
        let (viewModel, repository) = makeViewModel(outcome: .teacher)
        await viewModel.login()

        await viewModel.logout()

        #expect(repository.logoutCallCount == 1)
        #expect(viewModel.state == .idle)
    }

    @Test func retryAfterFailureCanSucceed() async {
        let (viewModel, repository) = makeViewModel(outcomes: [.failure, .student])

        await viewModel.login()
        #expect(viewModel.state == .failed)
        await viewModel.login()

        #expect(repository.loginCallCount == 2)
        #expect(viewModel.state == .loggedIn)
    }

    @Test func userCancelledLoginReturnsToIdle() async {
        let (viewModel, _) = makeViewModel(outcome: .cancelled)

        await viewModel.login()

        #expect(viewModel.state == .idle)
    }

    @Test func taskCancelledDuringLoginReturnsToIdle() async {
        let (viewModel, _) = makeViewModel(outcome: .student, delay: .seconds(10))

        let login = Task { await viewModel.login() }
        while viewModel.state != .loading {
            await Task.yield()
        }
        login.cancel()
        await login.value

        #expect(viewModel.state == .idle)
    }

    @Test func logoutAfterFailureReturnsToIdle() async {
        let (viewModel, repository) = makeViewModel(outcome: .failure)
        await viewModel.login()

        await viewModel.logout()

        #expect(repository.logoutCallCount == 1)
        #expect(viewModel.state == .idle)
    }

    @Test func failedLogoutStillReturnsToIdle() async {
        let (viewModel, repository) = makeViewModel(outcomes: [.teacher], logoutFails: true)
        await viewModel.login()

        await viewModel.logout()

        #expect(repository.logoutCallCount == 1)
        #expect(viewModel.state == .idle)
    }
}
