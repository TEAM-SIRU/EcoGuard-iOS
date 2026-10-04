import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct VerificationResultViewModelTests {
    private typealias Fixture = MockVerificationResultRepository.Fixture

    private func makeViewModel(
        _ scenario: MockVerificationResultRepository.Scenario,
        delay: Duration = .zero,
        failuresBeforeSuccess: Int = 0,
        error: Error = MockVerificationResultRepository.FetchFailedError()
    ) -> (VerificationResultViewModel, MockVerificationResultRepository) {
        let repository = MockVerificationResultRepository(
            scenario: scenario,
            delay: delay,
            failuresBeforeSuccess: failuresBeforeSuccess,
            error: error
        )
        let viewModel = VerificationResultViewModel(
            resultID: Fixture.id,
            fetchResultUseCase: FetchVerificationResultUseCase(verificationResultRepository: repository)
        )
        return (viewModel, repository)
    }

    @Test(arguments: [
        (MockVerificationResultRepository.Scenario.processing, VerificationResult.Status.processing),
        (.approved, .approved),
        (.rejected, .rejected),
        (.manualReview, .manualReview)
    ])
    func loadsResultForEachStatus(scenario: MockVerificationResultRepository.Scenario, status: VerificationResult.Status) async {
        let (viewModel, _) = makeViewModel(scenario)

        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.result(status: status)))
    }

    @Test func failureShowsFailedState() async {
        let (viewModel, _) = makeViewModel(.failure)

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }

    @Test func retryAfterFailureLoadsResult() async {
        let (viewModel, repository) = makeViewModel(.approved, failuresBeforeSuccess: 1)

        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.retry()

        #expect(viewModel.state == .loaded(Fixture.result(status: .approved)))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func loadDoesNotRefetchLoadedResult() async {
        let (viewModel, repository) = makeViewModel(.approved)

        await viewModel.load()
        await viewModel.load()

        #expect(repository.fetchCallCount == 1)
    }

    @Test func cancelledLoadStaysLoadingAndReloads() async {
        let (viewModel, repository) = makeViewModel(.approved, delay: .seconds(10))

        let task = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        // 화면을 떠나 취소돼도 실패 화면에 갇히지 않고, 다시 나타나면 새로 불러온다.
        #expect(viewModel.state == .loading)
        #expect(repository.fetchCallCount == 1)

        repository.delay = .zero
        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.result(status: .approved)))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func cancelledURLRequestWithoutTaskCancellationFails() async {
        let (viewModel, _) = makeViewModel(.approved, failuresBeforeSuccess: 1, error: URLError(.cancelled))

        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.retry()
        #expect(viewModel.state == .loaded(Fixture.result(status: .approved)))
    }

    @Test func cancelledRetryStaysLoadingNotFailed() async {
        let (viewModel, repository) = makeViewModel(.approved, failuresBeforeSuccess: 1)
        await viewModel.load()
        #expect(viewModel.state == .failed)
        repository.delay = .seconds(10)

        let task = Task { await viewModel.retry() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        #expect(viewModel.state == .loading)
    }

    @Test func loadRefetchesWhileProcessing() async {
        let (viewModel, repository) = makeViewModel(.processing)
        await viewModel.load()
        #expect(viewModel.state == .loaded(Fixture.result(status: .processing)))

        repository.scenario = .approved
        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.result(status: .approved)))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func refreshUpdatesProcessingResult() async {
        let (viewModel, repository) = makeViewModel(.processing)
        await viewModel.load()

        repository.scenario = .rejected
        await viewModel.refresh()

        #expect(viewModel.state == .loaded(Fixture.result(status: .rejected)))
    }

    @Test func failedRefreshKeepsProcessingResult() async {
        let (viewModel, repository) = makeViewModel(.processing)
        await viewModel.load()

        repository.scenario = .failure
        await viewModel.refresh()

        #expect(viewModel.state == .loaded(Fixture.result(status: .processing)))
    }

    @Test func refreshIgnoresFinalResult() async {
        let (viewModel, repository) = makeViewModel(.approved)
        await viewModel.load()

        await viewModel.refresh()

        #expect(repository.fetchCallCount == 1)
    }
}
