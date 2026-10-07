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

    /// Mock도 실제 도면을 쓰고, 함께 쓰는 Mock 상태의 배정 구역을 내 구역으로 표시한다.
    @Test func mockStoreZoneOpensItsLowestFloor() async {
        let repository = MockCleaningAreaRepository(store: MockStore(zoneCode: .mainCorridorF4), delay: .zero)
        let viewModel = CleaningAreaViewModel(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase(cleaningAreaRepository: repository))

        await viewModel.load()

        #expect(viewModel.selectedFloor?.id == "4F")
        #expect(viewModel.selectedFloor?.rows.joined().filter { $0.kind == .mine }.map(\.zoneCode) == [.mainCorridorF4])
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
        #expect(CleaningAreaFormatter.window(Fixture.area) == "07:20 – 08:10")
    }

    /// Mock 구역 이름·설명이 도면의 내 구역과 맞는다. 18개 구역 모두 이름이 있다.
    @Test func mockAreaFollowsZoneCode() {
        #expect(Set(Fixture.zones.keys) == Set(CleaningZoneCode.all))
        let area = Fixture.area(zoneCode: .mainStairA)
        #expect(area.range == "본관 계단 A")
        #expect(area.description == "1층→4층, 1층 현관 제외")
        #expect(area.zoneCode == .mainStairA)
    }

    /// 내 이름을 모르면(실제 서버, #55 전) 나를 따로 표시하지 않고 서버 순서 그대로 보여 준다.
    @Test func membersWithoutMyNameKeepOrder() {
        let area = MyCleaningArea(zoneCode: nil, range: "", description: "", startMinute: 0, endMinute: 0, memberNames: ["김서연", "이도윤"], myName: nil)
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
