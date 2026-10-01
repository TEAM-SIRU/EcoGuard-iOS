import Foundation
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

    @Test func nextRefreshDateFollowsPhase() async {
        let detail = MockRecruitmentRepository.Fixture.detail(phase: .open, appliedCount: 4)
        let (open, _) = makeViewModel(scenarios: [.open])
        let (upcoming, _) = makeViewModel(scenarios: [.upcoming])
        let (applied, _) = makeViewModel(scenarios: [.applied])
        let (full, _) = makeViewModel(scenarios: [.full])

        await open.load()
        await upcoming.load()
        await applied.load()
        await full.load()

        #expect(open.nextRefreshDate == detail.endDate)
        #expect(upcoming.nextRefreshDate == detail.startDate)
        #expect(applied.nextRefreshDate == nil)
        #expect(full.nextRefreshDate == nil)
    }

    /// 서버가 신청 가능으로 내려줘도 마감 시각이 지나면 다시 조회되기 전에 버튼을 끈다.
    @Test func canApplyOnlyBeforeEndDate() async {
        let endDate = MockRecruitmentRepository.Fixture.detail(phase: .open, appliedCount: 4).endDate
        let (viewModel, _) = makeViewModel(scenarios: [.open])
        #expect(!viewModel.canApply(at: endDate.addingTimeInterval(-60)))

        await viewModel.load()

        #expect(viewModel.canApply(at: endDate.addingTimeInterval(-1)))
        #expect(!viewModel.canApply(at: endDate))
        #expect(!viewModel.canApply(at: endDate.addingTimeInterval(60)))
    }

    @Test(arguments: [MockRecruitmentRepository.Scenario.full, .applied, .upcoming, .ended])
    func cannotApplyUnlessOpen(scenario: MockRecruitmentRepository.Scenario) async {
        let startDate = MockRecruitmentRepository.Fixture.detail(phase: .open, appliedCount: 0).startDate
        let (viewModel, _) = makeViewModel(scenarios: [scenario])

        await viewModel.load()

        #expect(!viewModel.canApply(at: startDate.addingTimeInterval(60)))
    }

    @Test func refreshAfterEndDateShowsEnded() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.open, .ended])
        await viewModel.load()

        await viewModel.refresh()

        #expect(repository.fetchCallCount == 2)
        #expect(status(viewModel) == .ended)
        #expect(viewModel.nextRefreshDate == nil)
    }

    @Test func refreshFailureKeepsCurrentScreen() async {
        let (viewModel, _) = makeViewModel(scenarios: [.open, .failure])
        await viewModel.load()

        await viewModel.refresh()

        #expect(status(viewModel) == .open)
    }

    @Test func refreshWithoutLoadedScreenLoads() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.failure, .applied])
        await viewModel.load()

        await viewModel.refresh()

        #expect(repository.fetchCallCount == 2)
        #expect(status(viewModel) == .applied(MockRecruitmentRepository.Fixture.application(.approved)))
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
