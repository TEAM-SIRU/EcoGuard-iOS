import Testing
@testable import EcoGuard

@MainActor
struct RecruitmentNoticeViewModelTests {
    private func makeViewModel(scenarios: [MockRecruitmentRepository.Scenario]) -> (RecruitmentNoticeViewModel, MockRecruitmentRepository) {
        let repository = MockRecruitmentRepository(scenarios: scenarios, delay: .zero)
        let viewModel = RecruitmentNoticeViewModel(fetchRecruitmentUseCase: FetchRecruitmentUseCase(recruitmentRepository: repository))
        return (viewModel, repository)
    }

    private func status(_ viewModel: RecruitmentNoticeViewModel) -> RecruitmentStatus? {
        guard case .loaded(let detail, _) = viewModel.state else { return nil }
        return detail.status
    }

    @Test func startsInLoading() {
        let (viewModel, _) = makeViewModel(scenarios: [.open])

        #expect(viewModel.state == .loading)
    }

    @Test func loadsDetailWithApplicant() async {
        let (viewModel, _) = makeViewModel(scenarios: [.open])

        await viewModel.load()

        #expect(viewModel.state == .loaded(
            MockRecruitmentRepository.Fixture.detail(phase: .open, appliedCount: 4),
            MockRecruitmentRepository.Fixture.applicant
        ))
    }

    @Test(arguments: [MockRecruitmentRepository.Scenario.open, .full, .applied, .upcoming, .ended])
    func mapsScenarioToStatus(scenario: MockRecruitmentRepository.Scenario) async {
        let expected: RecruitmentStatus? = switch scenario {
        case .open: .open
        case .full: .full
        case .applied: .applied(MockRecruitmentRepository.Fixture.application(.approved))
        case .upcoming: .upcoming
        case .ended: .ended
        case .none, .failure: nil
        }
        let (viewModel, _) = makeViewModel(scenarios: [scenario])

        await viewModel.load()

        #expect(status(viewModel) == expected)
    }

    @Test func noRecruitmentIsEmpty() async {
        let (viewModel, _) = makeViewModel(scenarios: [.none])

        await viewModel.load()

        #expect(viewModel.state == .empty)
    }

    @Test func failureThenRetrySucceeds() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.failure, .open])

        await viewModel.load()
        #expect(viewModel.state == .failed)
        await viewModel.retry()

        #expect(repository.fetchCallCount == 2)
        #expect(status(viewModel) == .open)
    }
}
