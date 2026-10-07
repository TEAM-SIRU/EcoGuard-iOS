import Foundation
import Testing
@testable import EcoGuard

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
struct ActivityRecordsViewModelTests {
    private let september = YearMonth(year: 2026, month: 9)
    private let august = YearMonth(year: 2026, month: 8)

    private func makeViewModel(
        scenarios: [MockActivityRepository.Scenario],
        delay: Duration = .zero,
        now: Date? = nil
    ) -> (ActivityRecordsViewModel, MockActivityRepository) {
        let today = now ?? MockActivityRepository.Fixture.today
        let repository = MockActivityRepository(scenarios: scenarios, delay: delay, now: { today })
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

    /// 빈 상태의 인증 버튼은 이번 달에만 둔다.
    @Test func onlyCurrentMonthIsCurrentMonthSelected() {
        let (viewModel, _) = makeViewModel(scenarios: [.empty])
        #expect(viewModel.isCurrentMonthSelected)

        viewModel.selectMonth(august)

        #expect(!viewModel.isCurrentMonthSelected)
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
        #expect(month.records != MockActivityRepository.Fixture.records)
    }

    /// Mock은 오늘 기준 이번 달·지난달에만 기록을 만든다. 그 전 달은 빈 달이다.
    @Test func mockGeneratesRecentMonthsRelativeToToday() async throws {
        // 2026-10-02(금) 09:00 KST
        let now = Date(timeIntervalSince1970: 1_790_866_800 + 9 * 3600)
        let repository = MockActivityRepository(scenario: .records, delay: .zero, now: { now })

        let october = try await repository.fetchMonth(year: 2026, month: 10)
        #expect(october.records.map(\.result) == [.reviewing, .approved])
        #expect(october.totalMinutes == 10)

        let septemberMonth = try await repository.fetchMonth(year: 2026, month: 9)
        #expect(septemberMonth.records == MockActivityRepository.Fixture.records)

        let august = try await repository.fetchMonth(year: 2026, month: 8)
        #expect(august.records.isEmpty)

        let generatedAugust = MockActivityRepository.Fixture.generatedRecords(in: YearMonth(year: 2026, month: 8), now: now)
        #expect(generatedAugust.count == 21)
        #expect(generatedAugust.filter { $0.result == .approved }.count == 19)
        #expect(generatedAugust.map(\.date) == generatedAugust.map(\.date).sorted(by: >))
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

    /// 탭을 떠나 취소되면 .loading으로 남아 돌아왔을 때 화면의 `.task`가 다시 불러온다.
    @Test func cancelledFirstLoadStaysLoadingForReload() async {
        let today = MockActivityRepository.Fixture.today
        let base = MockActivityRepository(scenarios: [.records], delay: .zero, now: { today })
        let repository = GatedActivityRepository(base: base)
        let viewModel = ActivityRecordsViewModel(
            fetchActivityMonthUseCase: FetchActivityMonthUseCase(activityRepository: repository),
            earliestMonth: YearMonth(year: 2026, month: 3),
            now: { today }
        )

        let load = Task { await viewModel.load() }
        await repository.gate.waitForHeldCall()
        load.cancel()
        await load.value
        #expect(viewModel.state == .loading)

        await viewModel.load()
        #expect(repository.gate.callCount == 2)
        #expect(base.requestedMonths == [september])
        #expect(loadedMonth(viewModel)?.month == september)
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

    /// 작업이 살아 있는데 온 `URLError.cancelled`는 요청이 끊긴 것이라 실패로 둔다.
    @Test func cancelledURLWhileTaskAliveIsFailure() async {
        let (viewModel, _) = makeViewModel(scenarios: [.cancelledURL])

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }

    /// 취소였다면 이전 화면으로 돌아갔을 다시 불러오기가 실패 화면으로 간다.
    @Test func cancelledURLDuringReloadIsFailure() async {
        let (viewModel, _) = makeViewModel(scenarios: [.records, .cancelledURL])
        await viewModel.load()

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }

    @Test func refreshRequestedWhileRefreshingFetchesOnceMore() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.records], delay: .milliseconds(100))
        await viewModel.load()

        let refresh = Task { await viewModel.refresh() }
        while repository.requestedMonths.count < 2 {
            await Task.yield()
        }
        await viewModel.refresh()
        await viewModel.refresh()
        await refresh.value

        // 진행 중에 두 번 요청돼도 끝난 뒤 한 번만 더 조회한다.
        #expect(repository.requestedMonths.count == 3)
    }

    private func makeViewModel(clock: TestClock) -> (ActivityRecordsViewModel, MockActivityRepository) {
        let repository = MockActivityRepository(scenarios: [.records], delay: .zero, now: { clock.now })
        let viewModel = ActivityRecordsViewModel(
            fetchActivityMonthUseCase: FetchActivityMonthUseCase(activityRepository: repository),
            earliestMonth: YearMonth(year: 2026, month: 3),
            now: { clock.now }
        )
        return (viewModel, repository)
    }

    @Test func returnAfterMonthRolloverMovesToNewCurrentMonth() async {
        let clock = TestClock(now: MockActivityRepository.Fixture.today)
        let (viewModel, _) = makeViewModel(clock: clock)
        await viewModel.load()

        clock.now = MockActivityRepository.Fixture.today.addingTimeInterval(3 * 24 * 3600)
        await viewModel.refreshOnReturn()

        #expect(viewModel.selectedMonth == YearMonth(year: 2026, month: 10))
        #expect(viewModel.state == .loading)
    }

    @Test func returnAfterMonthRolloverKeepsPastMonthSelection() async {
        let clock = TestClock(now: MockActivityRepository.Fixture.today)
        let (viewModel, repository) = makeViewModel(clock: clock)
        viewModel.selectMonth(august)
        await viewModel.load()

        clock.now = MockActivityRepository.Fixture.today.addingTimeInterval(3 * 24 * 3600)
        await viewModel.refreshOnReturn()

        #expect(viewModel.selectedMonth == august)
        #expect(repository.requestedMonths == [august, august])
        #expect(loadedMonth(viewModel)?.month == august)
    }

    @Test func returnInSameMonthRefreshes() async {
        let clock = TestClock(now: MockActivityRepository.Fixture.today)
        let (viewModel, repository) = makeViewModel(clock: clock)
        await viewModel.load()

        await viewModel.refreshOnReturn()

        #expect(viewModel.selectedMonth == september)
        #expect(repository.requestedMonths == [september, september])
    }

    @Test func returnWhileLoadingLeavesLoadToView() async {
        let clock = TestClock(now: MockActivityRepository.Fixture.today)
        let (viewModel, repository) = makeViewModel(clock: clock)

        await viewModel.refreshOnReturn()

        #expect(viewModel.state == .loading)
        #expect(repository.requestedMonths.isEmpty)
    }
}
