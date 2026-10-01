import Testing
@testable import EcoGuard

@MainActor
struct LoginViewModelTests {
    private func makeViewModel(
        outcome: MockAuthRepository.Outcome,
        delay: Duration = .zero
    ) -> (LoginViewModel, MockAuthRepository) {
        let repository = MockAuthRepository(outcome: outcome, delay: delay)
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
}
