import Foundation

/// 수동 DI. 앱 시작 시 한 번 만들고 화면별 ViewModel을 여기서 만든다.
final class DIContainer {
    /// 교사 안내 화면의 웹 관리자 주소. 없으면 복사·공유 버튼을 숨긴다.
    let webAdminURL: URL?

    private let authRepository: AuthRepository
    private let homeRepository: HomeRepository

    init(authRepository: AuthRepository, homeRepository: HomeRepository, webAdminURL: URL?) {
        self.authRepository = authRepository
        self.homeRepository = homeRepository
        self.webAdminURL = webAdminURL
    }

    /// 실제 OAuth·서버 구현 전까지 Mock을 쓴다.
    static func live() -> DIContainer {
        DIContainer(
            authRepository: MockAuthRepository(),
            homeRepository: MockHomeRepository(),
            webAdminURL: AppConfig.webAdminURL
        )
    }

    func makeLoginViewModel(state: LoginViewModel.State = .idle) -> LoginViewModel {
        LoginViewModel(
            loginUseCase: LoginUseCase(authRepository: authRepository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
            state: state
        )
    }

    func makeHomeViewModel(state: HomeViewModel.State = .loading) -> HomeViewModel {
        HomeViewModel(
            fetchHomeUseCase: FetchHomeUseCase(homeRepository: homeRepository),
            dismissNoticeUseCase: DismissNoticeUseCase(homeRepository: homeRepository),
            state: state
        )
    }
}

extension DIContainer {
    /// Preview용. 지연 없이 정해진 결과를 돌려주는 Mock을 쓴다.
    static func preview(
        outcome: MockAuthRepository.Outcome = .student,
        homeScenario: MockHomeRepository.Scenario = .notSubmitted,
        webAdminURL: URL? = nil
    ) -> DIContainer {
        DIContainer(
            authRepository: MockAuthRepository(outcome: outcome, delay: .zero),
            homeRepository: MockHomeRepository(scenario: homeScenario, delay: .zero),
            webAdminURL: webAdminURL
        )
    }
}
