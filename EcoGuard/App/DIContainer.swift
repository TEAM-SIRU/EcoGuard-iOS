import Foundation

/// 수동 DI. 앱 시작 시 한 번 만들고 화면별 ViewModel을 여기서 만든다.
final class DIContainer {
    /// 교사 안내 화면의 웹 관리자 주소. 없으면 복사·공유 버튼을 숨긴다.
    let webAdminURL: URL?

    private let authRepository: AuthRepository
    private let homeRepository: HomeRepository
    private let recruitmentRepository: RecruitmentRepository

    init(
        authRepository: AuthRepository,
        homeRepository: HomeRepository,
        recruitmentRepository: RecruitmentRepository,
        webAdminURL: URL?
    ) {
        self.authRepository = authRepository
        self.homeRepository = homeRepository
        self.recruitmentRepository = recruitmentRepository
        self.webAdminURL = webAdminURL
    }

    /// 실제 OAuth·서버 구현 전까지 Mock을 쓴다.
    static func live() -> DIContainer {
        DIContainer(
            authRepository: MockAuthRepository(),
            homeRepository: MockHomeRepository(),
            recruitmentRepository: MockRecruitmentRepository(),
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
