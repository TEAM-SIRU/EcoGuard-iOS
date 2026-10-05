import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct NoticeViewModelTests {
    private typealias Fixture = MockNoticeRepository.Fixture

    private func makeViewModel(
        scenarios: [MockNoticeRepository.Scenario],
        delay: Duration = .zero
    ) -> (NoticeViewModel, MockNoticeRepository) {
        let repository = MockNoticeRepository(scenarios: scenarios, delay: delay)
        let viewModel = NoticeViewModel(fetchNoticesUseCase: FetchNoticesUseCase(noticeRepository: repository))
        return (viewModel, repository)
    }

    @Test func loadSucceeds() async {
        let (viewModel, _) = makeViewModel(scenarios: [.loaded])

        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.notices))
    }

    @Test func loadFailureShowsFailed() async {
        let (viewModel, _) = makeViewModel(scenarios: [.failure])

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }

    @Test func failureThenRetrySucceeds() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.failure, .loaded])

        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.load()
        #expect(viewModel.state == .loaded(Fixture.notices))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func loadWhileLoadingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.loaded], delay: .milliseconds(50))

        async let first: Void = viewModel.load()
        async let second: Void = viewModel.load()
        _ = await (first, second)

        #expect(repository.fetchCallCount == 1)
    }

    @Test func cancelledFirstLoadStaysLoadingAndReloads() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.loaded], delay: .milliseconds(200))

        let task = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        // 화면을 떠나 취소돼도 실패 화면에 갇히지 않는다. 다시 나타나면 `.task`가 새로 불러온다.
        #expect(viewModel.state == .loading)

        await viewModel.load()
        #expect(viewModel.state == .loaded(Fixture.notices))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func cancelledRetryKeepsFailed() async {
        let repository = MockNoticeRepository(scenarios: [.loaded], delay: .seconds(10))
        let viewModel = NoticeViewModel(fetchNoticesUseCase: FetchNoticesUseCase(noticeRepository: repository), state: .failed)

        let task = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        // 다시 시도 중 화면을 떠나면 실패 화면 그대로 둔다.
        #expect(viewModel.state == .failed)
        #expect(repository.fetchCallCount == 1)
    }

    @Test func urlCancelledWhileTaskAliveIsFailure() async {
        let viewModel = NoticeViewModel(fetchNoticesUseCase: FetchNoticesUseCase(noticeRepository: URLCancelledRepository()))

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }
}

private struct URLCancelledRepository: NoticeRepository {
    func fetchNotices() async throws -> [Notice] {
        throw URLError(.cancelled)
    }

    func fetchNotice(id: Notice.ID) async throws -> Notice? {
        throw URLError(.cancelled)
    }
}
