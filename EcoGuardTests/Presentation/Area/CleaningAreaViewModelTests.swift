import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct CleaningAreaViewModelTests {
    private typealias Fixture = MockCleaningAreaRepository.Fixture

    private func makeViewModel(
        scenarios: [MockCleaningAreaRepository.Scenario],
        delay: Duration = .zero
    ) -> (CleaningAreaViewModel, MockCleaningAreaRepository) {
        let repository = MockCleaningAreaRepository(scenarios: scenarios, delay: delay)
        let viewModel = CleaningAreaViewModel(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase(cleaningAreaRepository: repository))
        return (viewModel, repository)
    }

    @Test func loadSelectsMyFloor() async {
        let (viewModel, _) = makeViewModel(scenarios: [.assigned])

        await viewModel.load()

        #expect(viewModel.state == .loaded(Fixture.assigned))
        #expect(viewModel.selectedFloor?.id == "2F")
        #expect(viewModel.selectedFloor?.rows.flatMap { $0 }.contains { $0.kind == .mine } == true)
    }

    @Test func unassignedHasNoFloor() async {
        let (viewModel, _) = makeViewModel(scenarios: [.unassigned])

        await viewModel.load()

        #expect(viewModel.state == .loaded(.unassigned))
        #expect(viewModel.selectedFloor == nil)
    }

    @Test func failureThenRetrySucceeds() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.failure, .assigned])

        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.load()
        #expect(viewModel.state == .loaded(Fixture.assigned))
        #expect(repository.fetchCallCount == 2)
    }

    @Test func selectFloorChangesPlan() async {
        let (viewModel, _) = makeViewModel(scenarios: [.assigned])
        await viewModel.load()

        viewModel.selectFloor(id: "3F")

        #expect(viewModel.selectedFloor?.name == "3층")
        #expect(viewModel.selectedFloor?.rows.flatMap { $0 }.contains { $0.kind == .mine } == false)
    }

    @Test func selectingUnknownFloorIsIgnored() async {
        let (viewModel, _) = makeViewModel(scenarios: [.assigned])
        await viewModel.load()

        viewModel.selectFloor(id: "9F")

        #expect(viewModel.selectedFloor?.id == "2F")
    }

    @Test func refreshKeepsSelectedFloor() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.assigned])
        await viewModel.load()
        viewModel.selectFloor(id: "4F")

        await viewModel.refresh()

        #expect(viewModel.selectedFloor?.id == "4F")
        #expect(repository.fetchCallCount == 2)
    }

    @Test func refreshFailureKeepsScreen() async {
        let (viewModel, _) = makeViewModel(scenarios: [.assigned, .failure])
        await viewModel.load()

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(Fixture.assigned))
    }

    @Test func refreshAfterUnassignedClearsFloor() async {
        let (viewModel, _) = makeViewModel(scenarios: [.assigned, .unassigned])
        await viewModel.load()

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(.unassigned))
        #expect(viewModel.selectedFloor == nil)
    }

    @Test func loadWhileLoadingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.assigned], delay: .milliseconds(50))

        async let first: Void = viewModel.load()
        async let second: Void = viewModel.load()
        _ = await (first, second)

        #expect(repository.fetchCallCount == 1)
    }

    @Test func cancelledFirstLoadStaysLoadingAndReloads() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.assigned], delay: .seconds(10))

        let task = Task { await viewModel.load() }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await task.value

        // 탭을 떠나 취소돼도 실패 화면에 갇히지 않고, 돌아오면 다시 불러온다.
        #expect(viewModel.state == .loading)
        #expect(repository.fetchCallCount == 1)
    }

    @Test func emptyFloorsAreTreatedAsUnassigned() async {
        let repository = EmptyFloorsRepository()
        let viewModel = CleaningAreaViewModel(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase(cleaningAreaRepository: repository))

        await viewModel.load()

        #expect(viewModel.state == .loaded(.unassigned))
        #expect(viewModel.selectedFloor == nil)
    }

    @Test func membersPutMeLast() {
        #expect(CleaningAreaFormatter.members(Fixture.area) == "김서연 · 이도윤 · 나(최민준)")
        #expect(CleaningAreaFormatter.window(Fixture.area) == "08:00 – 08:10")
    }

    /// 내 이름을 모르면(실제 서버, #55 전) 나를 따로 표시하지 않고 서버 순서 그대로 보여 준다.
    @Test func membersWithoutMyNameKeepOrder() {
        let area = MyCleaningArea(range: "", description: "", startMinute: 0, endMinute: 0, memberNames: ["김서연", "이도윤"], myName: nil)
        #expect(CleaningAreaFormatter.members(area) == "김서연 · 이도윤")
    }

    /// 작업이 살아 있는데 온 `URLError.cancelled`는 요청이 끊긴 것이라 실패로 둔다.
    @Test func urlCancelledWhileTaskAliveIsFailure() async {
        let viewModel = CleaningAreaViewModel(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase(cleaningAreaRepository: URLCancelledRepository()))

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }
}

private struct EmptyFloorsRepository: CleaningAreaRepository {
    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        .assigned(floors: [], myFloorID: "2F", area: MockCleaningAreaRepository.Fixture.area)
    }
}

private struct URLCancelledRepository: CleaningAreaRepository {
    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        throw URLError(.cancelled)
    }
}
