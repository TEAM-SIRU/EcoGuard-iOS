import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AppealHistoryViewModelTests {
    private typealias Fixture = MockAppealRepository.Fixture

    private func makeViewModel(
        _ scenario: MockAppealRepository.Scenario = .history,
        fetchFailuresBeforeSuccess: Int = 0,
        delay: Duration = .zero
    ) -> (AppealHistoryViewModel, MockAppealRepository) {
        let repository = MockAppealRepository(
            scenario: scenario,
            fetchFailuresBeforeSuccess: fetchFailuresBeforeSuccess,
            delay: delay
        )
        let viewModel = AppealHistoryViewModel(fetchAppealsUseCase: FetchAppealsUseCase(appealRepository: repository))
        return (viewModel, repository)
    }

    @Test func loadShowsHistory() async {
        let (viewModel, _) = makeViewModel()
        #expect(viewModel.state == .loading)

        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.history))
    }

    @Test func emptyHistoryLoadsEmptyList() async {
        let (viewModel, _) = makeViewModel(.empty)

        await viewModel.load()

        #expect(viewModel.state == .loaded([]))
    }

    @Test func failureThenRetryLoads() async {
        let (viewModel, repository) = makeViewModel(fetchFailuresBeforeSuccess: 1)

        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.retry()
        #expect(viewModel.state == .loaded(Fixture.history))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func loadAgainRefreshesReviewingStatus() async {
        let (viewModel, repository) = makeViewModel(.empty)
        await viewModel.load()

        repository.scenario = .history
        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.history))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func refreshFailureKeepsList() async {
        let (viewModel, repository) = makeViewModel()
        await viewModel.load()

        repository.scenario = .failure
        await viewModel.refresh()

        #expect(viewModel.state == .loaded(Fixture.history))
    }

    @Test func refreshBeforeLoadDoesNothing() async {
        let (viewModel, repository) = makeViewModel()

        await viewModel.refresh()

        #expect(viewModel.state == .loading)
        #expect(repository.fetchCallCount == 0)
    }

    @Test func loadWhileFetchingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(delay: .milliseconds(200))

        let first = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        await viewModel.load()
        await first.value

        #expect(repository.fetchCallCount == 1)
        #expect(viewModel.state == .loaded(Fixture.history))
    }

    @Test func cancelledLoadStaysLoadingAndReloads() async {
        let (viewModel, repository) = makeViewModel(delay: .seconds(10))

        let task = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        // 화면을 떠나 취소돼도 실패 화면에 갇히지 않고, 다시 나타나면 새로 불러온다.
        #expect(viewModel.state == .loading)

        repository.delay = .zero
        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.history))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func submittedAppealAppearsFirst() async throws {
        let (viewModel, repository) = makeViewModel()
        let result = try await SubmitAppealUseCase(appealRepository: repository).execute(
            AppealDraft(requestID: "request-1", verificationID: Fixture.target.verificationID, message: "내용", photos: []),
            unconfirmedAttempts: []
        )
        guard case .submitted(let submitted) = result else {
            Issue.record("처음 보낸 이의신청은 바로 접수돼야 한다")
            return
        }

        await viewModel.load()

        #expect(viewModel.state == .loaded([submitted] + Fixture.history))
    }
}
