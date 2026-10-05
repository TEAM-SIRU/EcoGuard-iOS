import Foundation

/// 수동 DI. 앱 시작 시 한 번 만들고 화면별 ViewModel을 여기서 만든다.
final class DIContainer {
    /// 교사 안내 화면의 웹 관리자 주소. 없으면 복사·공유 버튼을 숨긴다.
    let webAdminURL: URL?

    /// 로그인·로그아웃이 같은 저장소를 써야 해서 화면별 확장(`DIContainer+MyPage`)에서도 쓴다.
    let authRepository: AuthRepository
    /// 컨테이너를 만들 때(앱 시작) 키체인을 한 번만 읽어 둔다. `RootView`가 다시 만들어져도 다시 읽지 않는다.
    private let hadStoredSessionAtLaunch: Bool
    private let homeRepository: HomeRepository
    /// 실제 저장소들이 같이 쓰는 클라이언트. 토큰(`AuthSession`)은 로그인 저장소와 하나를 쓴다. 서버 주소가 없으면(Mock) nil.
    /// 화면별 확장(`DIContainer+Notice` 등)에서 써서 읽기는 열어 둔다.
    private(set) lazy var apiClient: APIClient? = (authRepository as? AuthRepositoryImpl)?.apiClient
    /// 모집 공고·신청·결과 화면이 같은 저장소를 쓴다(신청할 공고 ID를 들고 있다).
    private lazy var recruitmentRepository: RecruitmentRepository =
        apiClient.map { RecruitmentRepositoryImpl(apiClient: $0) } ?? MockRecruitmentRepository()

    /// `recruitmentRepository`를 주지 않으면 서버 주소에 따라 실제 구현이나 Mock을 쓴다.
    init(
        authRepository: AuthRepository,
        homeRepository: HomeRepository,
        recruitmentRepository: RecruitmentRepository? = nil,
        webAdminURL: URL?
    ) {
        self.authRepository = authRepository
        self.hadStoredSessionAtLaunch = authRepository.hasStoredSession()
        self.homeRepository = homeRepository
        self.webAdminURL = webAdminURL
        if let recruitmentRepository {
            self.recruitmentRepository = recruitmentRepository
        }
    }

    /// 서버 주소(`ECO_API_HOST`)가 정해지기 전까지 Mock을 쓴다. 저장소마다 실제 구현이 생기는 대로 바꾼다.
    static func live() -> DIContainer {
        DIContainer(
            authRepository: makeAuthRepository(apiBaseURL: AppConfig.apiBaseURL),
            homeRepository: MockHomeRepository(),
            webAdminURL: AppConfig.webAdminURL
        )
    }

    /// 서버 주소가 없으면 Mock, 있으면 키체인에 토큰을 두는 실제 저장소.
    /// 앱을 지웠다 다시 깔면 UserDefaults는 비지만 키체인은 남는다. 첫 실행이면 이전 설치의 토큰을 지운다.
    static func makeAuthRepository(
        apiBaseURL: URL?,
        session: URLSession = .shared,
        tokenStore: TokenStore = KeychainTokenStore(),
        defaults: UserDefaults = .standard
    ) -> AuthRepository {
        guard let apiBaseURL else { return MockAuthRepository() }
        if !defaults.bool(forKey: hasLaunchedKey) {
            tokenStore.clear()
            defaults.set(true, forKey: hasLaunchedKey)
        }
        let httpClient = HTTPClient(baseURL: apiBaseURL, session: session)
        let apiClient = APIClient(
            httpClient: httpClient,
            authSession: AuthSession(tokenStore: tokenStore, httpClient: httpClient)
        )
        // TODO: dataGSM OAuth 연동 때 인가 코드를 받아 오는 구현으로 바꾼다. 그 전까지 실제 모드 로그인은 실패한다.
        return AuthRepositoryImpl(apiClient: apiClient, authorizationCode: { throw AuthorizationCodeUnavailableError() })
    }

    private static let hasLaunchedKey = "auth.hasLaunchedBefore"

    /// `state`를 주지 않으면 앱 시작 때 저장된 토큰이 있었을 경우 로그인 유지(`.loggedIn`)로 시작한다.
    /// 교사는 토큰을 저장하지 않으므로 저장된 토큰은 학생 세션이다.
    func makeLoginViewModel(state: LoginViewModel.State? = nil) -> LoginViewModel {
        LoginViewModel(
            loginUseCase: LoginUseCase(authRepository: authRepository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
            state: state ?? (hadStoredSessionAtLaunch ? .loggedIn : .idle)
        )
    }

    func makeHomeViewModel(state: HomeViewModel.State = .loading) -> HomeViewModel {
        HomeViewModel(
            fetchHomeUseCase: FetchHomeUseCase(homeRepository: homeRepository),
            dismissNoticeUseCase: DismissNoticeUseCase(homeRepository: homeRepository),
            state: state
        )
    }

    func makeRecruitmentNoticeViewModel(state: RecruitmentNoticeViewModel.State = .loading) -> RecruitmentNoticeViewModel {
        RecruitmentNoticeViewModel(
            fetchRecruitmentUseCase: FetchRecruitmentUseCase(recruitmentRepository: recruitmentRepository),
            state: state
        )
    }

    func makeRecruitmentApplyViewModel(applicant: Applicant, capacityPerClass: Int) -> RecruitmentApplyViewModel {
        RecruitmentApplyViewModel(
            applicant: applicant,
            capacityPerClass: capacityPerClass,
            applyRecruitmentUseCase: ApplyRecruitmentUseCase(recruitmentRepository: recruitmentRepository)
        )
    }

    /// `outcome`을 넘기면 신청 직후 결과를 그대로 보여 주고, nil이면 내 신청을 불러온다.
    func makeApplicationResultViewModel(outcome: ApplicationOutcome? = nil) -> ApplicationResultViewModel {
        ApplicationResultViewModel(
            outcome: outcome,
            fetchMyApplicationUseCase: FetchMyApplicationUseCase(recruitmentRepository: recruitmentRepository)
        )
    }
}

/// dataGSM OAuth가 아직 없어 인가 코드를 받을 수 없다.
struct AuthorizationCodeUnavailableError: Error {}

extension DIContainer {
    /// Preview용. 지연 없이 정해진 결과를 돌려주는 Mock을 쓴다.
    static func preview(
        outcome: MockAuthRepository.Outcome = .student,
        homeScenario: MockHomeRepository.Scenario = .notSubmitted,
        recruitmentScenario: MockRecruitmentRepository.Scenario = .open,
        applyOutcomes: [MockRecruitmentRepository.ApplyOutcome] = [.approved],
        webAdminURL: URL? = nil
    ) -> DIContainer {
        DIContainer(
            authRepository: MockAuthRepository(outcome: outcome, delay: .zero),
            homeRepository: MockHomeRepository(scenario: homeScenario, delay: .zero),
            recruitmentRepository: MockRecruitmentRepository(
                scenario: recruitmentScenario,
                applyOutcomes: applyOutcomes,
                delay: .zero
            ),
            webAdminURL: webAdminURL
        )
    }
}
