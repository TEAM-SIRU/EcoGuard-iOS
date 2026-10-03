import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct ActivityRecordsViewModelTests {
    private let september = YearMonth(year: 2026, month: 9)
    private let august = YearMonth(year: 2026, month: 8)

    private func makeViewModel(
        scenarios: [MockActivityRepository.Scenario],
        delay: Duration = .zero,
        now: Date? = nil
    ) -> (ActivityRecordsViewModel, MockActivityRepository) {
        let repository = MockActivityRepository(scenarios: scenarios, delay: delay)
        let today = now ?? MockActivityRepository.Fixture.today
        let viewModel = ActivityRecordsViewModel(
            fetchActivityMonthUseCase: FetchActivityMonthUseCase(activityRepository: repository),
            earliestMonth: YearMonth(year: 2026, month: 3),
            now: { today }
        )
        return (viewModel, repository)
    }

    private func loadedMonth(_ viewModel: ActivityRecordsViewModel) -> ActivityMonth? {
        guard case .loaded(let month) = viewModel.state else { return nil }
        return month
    }

    @Test func startsInLoadingOnCurrentKSTMonth() {
        // KST 10/1 00:30 = UTC 9/30. 기기 시간대가 아니라 KST 기준 달로 시작한다.
        let now = Date(timeIntervalSince1970: 1_790_782_200)
        let (viewModel, _) = makeViewModel(scenarios: [.records], now: now)

        #expect(viewModel.state == .loading)
        #expect(viewModel.selectedMonth == YearMonth(year: 2026, month: 10))
    }

    @Test func loadComputesStatsAndMinutes() async throws {
        let (viewModel, repository) = makeViewModel(scenarios: [.records])

        await viewModel.load()

        let month = try #require(loadedMonth(viewModel))
        #expect(repository.requestedMonths == [september])
        #expect(month.totalMinutes == 70)
        #expect(month.count(of: .approved) == 7)
        #expect(month.count(of: .rejected) == 1)
        #expect(month.count(of: .notSubmitted) == 1)
        #expect(month.count(of: .reviewing) == 1)
        #expect(viewModel.sections.map(\.weeksAgo) == [0, 1, 2])
    }

    @Test func approvalEarnsTenMinutes() {
        #expect(ActivityRecord.minutesPerApproval == 10)
        let approved = MockActivityRepository.Fixture.records.filter { $0.result == .approved }
        #expect(approved.allSatisfy { $0.earnedMinutes == 10 })
        #expect(MockActivityRepository.Fixture.records.filter { $0.result != .approved }.allSatisfy { $0.earnedMinutes == 0 })
    }

    @Test func selectingMonthRefetchesThatMonth() async throws {
        let (viewModel, repository) = makeViewModel(scenarios: [.records])
        await viewModel.load()

        viewModel.selectMonth(august)
        #expect(viewModel.state == .loading)
        await viewModel.load()

        #expect(repository.requestedMonths == [september, august])
        #expect(viewModel.selectedMonth == august)
        let month = try #require(loadedMonth(viewModel))
        #expect(month.month == august)
        #expect(month.records.isEmpty)
        #expect(month.totalMinutes == 0)
    }

    @Test(arguments: [(2026, 10), (2027, 1), (2026, 2), (2026, 9)])
    func ignoresMonthsOutsideRangeOrSame(year: Int, month: Int) async {
        let (viewModel, _) = makeViewModel(scenarios: [.records])
        await viewModel.load()
        let loaded = viewModel.state

        viewModel.selectMonth(YearMonth(year: year, month: month))

        #expect(viewModel.selectedMonth == september)
        #expect(viewModel.state == loaded)
    }

    @Test func selectableMonthsEndAtCurrentMonth() {
        let (viewModel, _) = makeViewModel(scenarios: [.records])

        #expect(viewModel.selectableMonths == YearMonth(year: 2026, month: 3)...september)
    }

    @Test func monthChangeDiscardsInFlightResponse() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.records], delay: .milliseconds(100))
        let firstLoad = Task { await viewModel.load() }
        while repository.requestedMonths.isEmpty {
            await Task.yield()
        }

        viewModel.selectMonth(august)
        await firstLoad.value

        // 9월 응답이 늦게 와도 8월 화면을 덮지 않는다.
        #expect(viewModel.state == .loading)
        await viewModel.load()
        #expect(loadedMonth(viewModel)?.month == august)
    }

    @Test func monthChangeDiscardsInFlightRefresh() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.records], delay: .milliseconds(100))
        await viewModel.load()
        let refresh = Task { await viewModel.refresh() }
        while repository.requestedMonths.count < 2 {
            await Task.yield()
        }

        viewModel.selectMonth(august)
        await refresh.value

        #expect(viewModel.state == .loading)
    }

    @Test func emptyMonthLoadsWithZeroStats() async throws {
        let (viewModel, _) = makeViewModel(scenarios: [.empty])

        await viewModel.load()

        let month = try #require(loadedMonth(viewModel))
        #expect(month.records.isEmpty)
        #expect(month.totalMinutes == 0)
        #expect(viewModel.sections.isEmpty)
    }

    @Test func failureThenRetryLoads() async {
        let (viewModel, _) = makeViewModel(scenarios: [.failure, .records])

        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.retry()
        #expect(loadedMonth(viewModel)?.totalMinutes == 70)
    }

    @Test func refreshFailureKeepsContent() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.records, .failure])
        await viewModel.load()
        let loaded = viewModel.state

        await viewModel.refresh()

        #expect(repository.requestedMonths.count == 2)
        #expect(viewModel.state == loaded)
    }

    @Test func refreshWhenFailedLoadsAgain() async {
        let (viewModel, _) = makeViewModel(scenarios: [.failure, .records])
        await viewModel.load()

        await viewModel.refresh()

        #expect(loadedMonth(viewModel)?.month == september)
    }

    @Test func cancelledFirstLoadDoesNotStayLoading() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.records], delay: .seconds(10))

        let load = Task { await viewModel.load() }
        while repository.requestedMonths.isEmpty {
            await Task.yield()
        }
        load.cancel()
        await load.value

        #expect(viewModel.state == .failed)
    }

    @Test func cancelledReloadReturnsToPreviousContent() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.records], delay: .milliseconds(200))
        await viewModel.load()
        let loaded = viewModel.state

        let reload = Task { await viewModel.load() }
        while repository.requestedMonths.count < 2 {
            await Task.yield()
        }
        reload.cancel()
        await reload.value

        #expect(viewModel.state == loaded)
    }
}
