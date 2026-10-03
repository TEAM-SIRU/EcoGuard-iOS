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

    @Test func membersPutMeLast() {
        #expect(CleaningAreaFormatter.members(Fixture.area) == "김서연 · 이도윤 · 나(최민준)")
        #expect(CleaningAreaFormatter.window(Fixture.area) == "08:00 – 08:10")
    }
}
