/// 수동 DI. 앱 시작 시 한 번 만들고 화면별 ViewModel을 여기서 만든다.
final class DIContainer {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    /// 실제 OAuth 구현 전까지 Mock을 쓴다.
    static func live() -> DIContainer {
        DIContainer(authRepository: MockAuthRepository())
    }

    func makeLoginViewModel(state: LoginViewModel.State = .idle) -> LoginViewModel {
        LoginViewModel(
            loginUseCase: LoginUseCase(authRepository: authRepository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
            state: state
        )
    }
}

extension DIContainer {
    /// Preview용. 지연 없이 정해진 결과를 돌려주는 Mock을 쓴다.
    static func preview(outcome: MockAuthRepository.Outcome = .student) -> DIContainer {
        DIContainer(authRepository: MockAuthRepository(outcome: outcome, delay: .zero))
    }
}
