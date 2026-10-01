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
struct HomeViewModelTests {
    private let now = Date(timeIntervalSinceReferenceDate: 0)

    private func makeViewModel(
        scenarios: [MockHomeRepository.Scenario],
        delay: Duration = .zero
    ) -> (HomeViewModel, MockHomeRepository) {
        let repository = MockHomeRepository(scenarios: scenarios, delay: delay, now: { now })
        let viewModel = HomeViewModel(
            fetchHomeUseCase: FetchHomeUseCase(homeRepository: repository),
            dismissNoticeUseCase: DismissNoticeUseCase(homeRepository: repository)
        )
        return (viewModel, repository)
    }

    private func loadedSummary(_ viewModel: HomeViewModel) -> HomeSummary? {
        guard case .loaded(let summary) = viewModel.state else { return nil }
        return summary
    }

    private func todayVerification(_ viewModel: HomeViewModel) -> TodayVerification? {
        guard case .active(let cleaning) = loadedSummary(viewModel)?.status else { return nil }
        return cleaning.today.verification
    }

    @Test func startsInLoading() {
        let (viewModel, _) = makeViewModel(scenarios: [.notSubmitted])

        #expect(viewModel.state == .loading)
    }

    @Test(arguments: [
        (MockHomeRepository.Scenario.notSubmitted, TodayVerification.open(deadline: Date(timeIntervalSinceReferenceDate: 332))),
        (.aiReviewing, .aiReviewing(submittedAt: MockHomeRepository.Fixture.submittedAt)),
        (.teacherReviewing, .teacherReviewing(submittedAt: MockHomeRepository.Fixture.submittedAt)),
        (.approved, .approved(earnedMinutes: 10)),
        (.rejected, .rejected(reason: "사진에 청소 구역이 잘 보이지 않아요")),
        (.notOpenYet, .notOpenYet(opensAt: MockHomeRepository.Fixture.opensAt(onDayOf: Date(timeIntervalSinceReferenceDate: 0))))
    ])
    func activeScenarioMapsToTodayVerification(scenario: MockHomeRepository.Scenario, expected: TodayVerification) async {
        let (viewModel, _) = makeViewModel(scenarios: [scenario])

        await viewModel.load()

        #expect(todayVerification(viewModel) == expected)
    }

    @Test func recruitingScenarioMapsToRecruiting() async {
        let (viewModel, _) = makeViewModel(scenarios: [.recruiting])

        await viewModel.load()

        let expected = Recruitment(semester: 2, capacityPerClass: 6, className: "2학년 3반", appliedCount: 4)
        #expect(loadedSummary(viewModel)?.status == .recruiting(expected))
        #expect(loadedSummary(viewModel)?.notice == MockHomeRepository.Fixture.notice)
    }

    @Test func awaitingAssignmentScenarioMapsToAwaitingAssignment() async {
        let (viewModel, _) = makeViewModel(scenarios: [.awaitingAssignment])

        await viewModel.load()

        #expect(loadedSummary(viewModel)?.status == .awaitingAssignment)
    }

    @Test func excludedScenarioMapsToExcludedWithReason() async {
        let (viewModel, _) = makeViewModel(scenarios: [.excluded])

        await viewModel.load()

        #expect(loadedSummary(viewModel)?.status == .excluded(reason: "본인 요청으로 활동을 중단했어요."))
    }

    @Test func approvedScenarioCountsTodayInWeek() async {
        let (viewModel, _) = makeViewModel(scenarios: [.approved])

        await viewModel.load()

        guard case .active(let cleaning) = loadedSummary(viewModel)?.status else {
            Issue.record("활동 중 상태가 아니다")
            return
        }
        #expect(cleaning.week.completedCount == 2)
        #expect(cleaning.week.days.count == 5)
    }

    @Test func failedFetchMovesToFailed() async {
        let (viewModel, _) = makeViewModel(scenarios: [.failure])

        await viewModel.load()

        #expect(viewModel.state == .failed)
    }

    @Test func retryAfterFailureCanSucceed() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.failure, .approved])
        await viewModel.load()
        #expect(viewModel.state == .failed)

        await viewModel.retry()

        #expect(repository.fetchCallCount == 2)
        #expect(todayVerification(viewModel) == .approved(earnedMinutes: 10))
    }

    @Test func retryShowsLoadingWhileFetching() async {
        let (viewModel, _) = makeViewModel(scenarios: [.failure, .approved], delay: .milliseconds(200))
        await viewModel.load()

        let retry = Task { await viewModel.retry() }
        while viewModel.state != .loading {
            await Task.yield()
        }

        #expect(viewModel.state == .loading)
        await retry.value
        #expect(todayVerification(viewModel) == .approved(earnedMinutes: 10))
    }

    @Test func loadWhileFetchingIsIgnored() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.notSubmitted], delay: .milliseconds(200))

        let firstLoad = Task { await viewModel.load() }
        while repository.fetchCallCount == 0 {
            await Task.yield()
        }
        await viewModel.load()
        await firstLoad.value

        #expect(repository.fetchCallCount == 1)
    }

    @Test func dismissNoticeHidesNoticeAndTellsRepository() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.notSubmitted])
        await viewModel.load()
        #expect(loadedSummary(viewModel)?.notice != nil)

        await viewModel.dismissNotice()

        #expect(loadedSummary(viewModel)?.notice == nil)
        #expect(todayVerification(viewModel) != nil)
        #expect(repository.dismissedNoticeIDHistory == [MockHomeRepository.Fixture.notice.id])
    }

    @Test func dismissedNoticeStaysHiddenAfterReload() async {
        let (viewModel, _) = makeViewModel(scenarios: [.notSubmitted])
        await viewModel.load()
        await viewModel.dismissNotice()

        await viewModel.load()

        #expect(loadedSummary(viewModel)?.notice == nil)
    }

    // MARK: - 재조회

    /// 2026-09-29(화) KST 시각.
    private func kst(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        let components = DateComponents(year: 2026, month: 9, day: 29, hour: hour, minute: minute, second: second)
        return MockHomeRepository.Fixture.calendar.date(from: components) ?? .distantPast
    }

    @Test func refreshAtOpeningTimeTurnsVerificationOn() async {
        let clock = TestClock(now: kst(7, 59))
        let repository = MockHomeRepository(scenarios: [.notOpenYet, .notSubmitted], delay: .zero, now: { clock.now })
        let viewModel = HomeViewModel(
            fetchHomeUseCase: FetchHomeUseCase(homeRepository: repository),
            dismissNoticeUseCase: DismissNoticeUseCase(homeRepository: repository)
        )
        await viewModel.load()
        #expect(viewModel.nextRefreshDate == kst(8, 0))
        #expect(viewModel.canVerify(at: clock.now) == false)

        clock.now = kst(8, 0)
        await viewModel.refresh()

        let deadline = kst(8, 5, 32)
        #expect(todayVerification(viewModel) == .open(deadline: deadline))
        #expect(viewModel.canVerify(at: clock.now))
        #expect(viewModel.nextRefreshDate == deadline)
    }

    @Test func verifyButtonTurnsOffAtDeadlineBeforeRefresh() async {
        let (viewModel, _) = makeViewModel(scenarios: [.notSubmitted])
        await viewModel.load()
        let deadline = now.addingTimeInterval(MockHomeRepository.Fixture.remainingUntilDeadline)

        #expect(viewModel.canVerify(at: deadline.addingTimeInterval(-1)))
        #expect(viewModel.canVerify(at: deadline) == false)
        #expect(viewModel.canVerify(at: deadline.addingTimeInterval(60)) == false)
    }

    @Test func noRefreshDateAfterSubmission() async {
        let (viewModel, _) = makeViewModel(scenarios: [.aiReviewing])
        await viewModel.load()

        #expect(viewModel.nextRefreshDate == nil)
        #expect(viewModel.canVerify(at: now) == false)
    }

    @Test func refreshKeepsContentWhileFetching() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.notSubmitted, .aiReviewing], delay: .milliseconds(200))
        await viewModel.load()

        let refresh = Task { await viewModel.refresh() }
        while repository.fetchCallCount < 2 {
            await Task.yield()
        }

        #expect(viewModel.state != .loading)
        await refresh.value
        #expect(todayVerification(viewModel) == .aiReviewing(submittedAt: MockHomeRepository.Fixture.submittedAt))
    }

    @Test func failedRefreshKeepsCurrentContent() async {
        let (viewModel, _) = makeViewModel(scenarios: [.approved, .failure])
        await viewModel.load()

        await viewModel.refresh()

        #expect(todayVerification(viewModel) == .approved(earnedMinutes: 10))
    }

    @Test func refreshAfterFailureLoadsAgain() async {
        let (viewModel, _) = makeViewModel(scenarios: [.failure, .approved])
        await viewModel.load()

        await viewModel.refresh()

        #expect(todayVerification(viewModel) == .approved(earnedMinutes: 10))
    }

    // MARK: - 취소

    @Test func cancelledFirstLoadDoesNotStayLoading() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.notSubmitted], delay: .seconds(10))

        let load = Task { await viewModel.load() }
        while repository.fetchCallCount == 0 {
            await Task.yield()
        }
        load.cancel()
        await load.value

        #expect(viewModel.state == .failed)
    }

    @Test func cancelledReloadReturnsToPreviousContent() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.approved, .rejected], delay: .milliseconds(200))
        await viewModel.load()
        let loaded = viewModel.state

        let reload = Task { await viewModel.load() }
        while repository.fetchCallCount < 2 {
            await Task.yield()
        }
        reload.cancel()
        await reload.value

        #expect(viewModel.state == loaded)
    }

    @Test func dismissNoticeWithoutNoticeDoesNothing() async {
        let (viewModel, repository) = makeViewModel(scenarios: [.approved])
        await viewModel.load()

        await viewModel.dismissNotice()

        #expect(repository.dismissedNoticeIDHistory.isEmpty)
    }
}
