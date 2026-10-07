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
    private let recruitmentRepository: RecruitmentRepository
    /// Mock 저장소들이 같이 쓰는 상태(오늘 날짜·기록·신청·제출). 화면별 확장도 Mock을 만들 때 넘긴다.
    let mockStore: MockStore
    /// 기기 청소 알림. 마이페이지 스위치와 앱 셸(배정 구역이 바뀔 때, 로그아웃)이 같이 쓴다.
    let cleaningReminderScheduler: CleaningReminderScheduler
    /// 실제 서버 저장소가 같이 쓴다. 로그인 저장소와 같은 `AuthSession`이라 토큰 재발급이 한 번만 일어난다.
    /// 서버 주소가 없으면(로그인이 Mock) nil이고 저장소는 Mock을 쓴다. 화면별 확장에서도 써서 `private`이 아니다.
    lazy var apiClient: APIClient? = (authRepository as? AuthRepositoryImpl)?.apiClient

    init(
        authRepository: AuthRepository,
        homeRepository: HomeRepository,
        recruitmentRepository: RecruitmentRepository,
        webAdminURL: URL?,
        mockStore: MockStore = MockStore(),
        cleaningReminderScheduler: CleaningReminderScheduler = MockCleaningReminderScheduler()
    ) {
        self.authRepository = authRepository
        self.hadStoredSessionAtLaunch = authRepository.hasStoredSession()
        self.homeRepository = homeRepository
        self.recruitmentRepository = recruitmentRepository
        self.webAdminURL = webAdminURL
        self.mockStore = mockStore
        self.cleaningReminderScheduler = cleaningReminderScheduler
    }

    /// 서버 주소(`ECO_API_HOST`)가 비어 있거나 Mock 전환(`AppConfig.usesMockRepositories`)이 켜져 있으면 Mock을 쓴다.
    static func live() -> DIContainer {
        let authRepository = makeAuthRepository(apiBaseURL: AppConfig.usesMockRepositories ? nil : AppConfig.apiBaseURL)
        // 모집 공고·신청·결과 화면이 같은 저장소를 쓴다(신청할 공고 ID를 들고 있다). `AuthSession`은 로그인 저장소와 같다.
        let apiClient = (authRepository as? AuthRepositoryImpl)?.apiClient
        let recruitmentScenario: MockRecruitmentRepository.Scenario = mockScenario("ECO_MOCK_RECRUITMENT_SCENARIO") ?? .open
        let mockStore = MockStore(
            homeScenario: mockScenario("ECO_MOCK_HOME_SCENARIO") ?? .notSubmitted,
            recruitmentScenario: recruitmentScenario,
            zoneCode: mockZoneCode ?? MockCleaningAreaRepository.Fixture.zoneCode
        )
        return DIContainer(
            authRepository: authRepository,
            homeRepository: MockHomeRepository(store: mockStore),
            recruitmentRepository: apiClient.map {
                RecruitmentRepositoryImpl(apiClient: $0, currentUserRepository: CurrentUserRepositoryImpl(apiClient: $0))
            } ?? MockRecruitmentRepository(scenario: recruitmentScenario, store: mockStore),
            webAdminURL: AppConfig.webAdminURL,
            mockStore: mockStore,
            // 로컬 알림은 서버와 상관없어 Mock 모드에서도 실제로 건다.
            cleaningReminderScheduler: CleaningReminderSchedulerImpl()
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
        // dataGSM OAuth 설정(클라이언트 ID·리다이렉트 URI·콜백 주소)이 비어 있으면 실제 모드 로그인은 실패한다.
        let authorizer = AppConfig.gsmOAuthConfiguration.map {
            GsmOAuthAuthorizer(configuration: $0, session: SystemWebAuthenticationSession())
        }
        return AuthRepositoryImpl(apiClient: apiClient, authorizationCode: {
            guard let authorizer else { throw AuthorizationCodeUnavailableError() }
            return try await authorizer.authorizationCode()
        })
    }

    private static let hasLaunchedKey = "auth.hasLaunchedBefore"

    /// Mock 저장소가 돌려줄 상태. UI 테스트가 DEBUG 빌드에서 환경 변수(`ECO_MOCK_HOME_SCENARIO=excluded`처럼 케이스 이름)로 고른다.
    /// 값이 없거나 Release 빌드면 nil이고 각 Mock의 기본 상태를 쓴다.
    static func mockScenario<Scenario: CaseIterable>(_ key: String) -> Scenario? {
        #if DEBUG
        let name = ProcessInfo.processInfo.environment[key]
        return Scenario.allCases.first { "\($0)" == name }
        #else
        return nil
        #endif
    }

    /// Mock 배정 구역. DEBUG 빌드에서 환경 변수(`ECO_MOCK_ZONE_CODE=main_stair_a`처럼 서버 구역 코드)로 고른다.
    private static var mockZoneCode: CleaningZoneCode? {
        #if DEBUG
        ProcessInfo.processInfo.environment["ECO_MOCK_ZONE_CODE"].map { CleaningZoneCode(rawValue: $0) }
        #else
        nil
        #endif
    }

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
        let homeRepository: HomeRepository = apiClient.map { HomeRepositoryImpl(apiClient: $0) } ?? self.homeRepository
        return HomeViewModel(
            fetchHomeUseCase: FetchHomeUseCase(homeRepository: homeRepository),
            dismissNoticeUseCase: DismissNoticeUseCase(homeRepository: homeRepository),
            state: state
        )
    }

    /// 배정 구역·시각이 바뀌거나 로그아웃했을 때 앱 셸(`RootView`)이 청소 알림을 다시 맞춘다.
    func makeSyncCleaningReminderUseCase(
        notificationSettingRepository: NotificationSettingRepository = NotificationSettingRepositoryImpl()
    ) -> SyncCleaningReminderUseCase {
        SyncCleaningReminderUseCase(
            notificationSettingRepository: notificationSettingRepository,
            cleaningReminderScheduler: cleaningReminderScheduler
        )
    }

    /// 로그인 후 메인에 처음 들어왔을 때 청소 알림 권한을 한 번 묻는다.
    /// Mock 모드(서버 주소 없음·Mock 전환, UI 테스트 포함)에서는 묻지 않아 nil.
    func makeRequestInitialCleaningReminderUseCase(
        notificationSettingRepository: NotificationSettingRepository = NotificationSettingRepositoryImpl()
    ) -> RequestInitialCleaningReminderUseCase? {
        guard apiClient != nil else { return nil }
        return RequestInitialCleaningReminderUseCase(
            notificationSettingRepository: notificationSettingRepository,
            cleaningReminderScheduler: cleaningReminderScheduler
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

/// dataGSM OAuth 설정(클라이언트 ID·리다이렉트 URI·콜백 주소)이 비어 있어 인가 코드를 받을 수 없다.
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
