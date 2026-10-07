import Foundation
import Testing
@testable import EcoGuard

/// 서버 없이 돌릴 때 Mock 저장소끼리 같은 데이터를 보여 주는지(#82). 시계는 고정한다.
@MainActor
struct MockStoreTests {
    /// 2026-10-07(수) 09:00 KST.
    private static let wednesday = kst(2026, 10, 7, 9, 0)
    /// 2026-10-10(토) 10:00 KST.
    private static let saturday = kst(2026, 10, 10, 10, 0)

    private static func kst(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        MockStore.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private func activeCleaning(_ summary: HomeSummary) -> ActiveCleaning? {
        guard case .active(let cleaning) = summary.status else { return nil }
        return cleaning
    }

    private func fetchHome(_ store: MockStore) async throws -> HomeSummary {
        try await MockHomeRepository(store: store, delay: .zero).fetchHome()
    }

    private func fetchMonth(_ store: MockStore, _ month: YearMonth) async throws -> ActivityMonth {
        try await MockActivityRepository(store: store, delay: .zero).fetchMonth(year: month.year, month: month.month)
    }

    // MARK: - 날짜

    @Test func todayFollowsClockAndWeekendUsesFriday() {
        #expect(MockStore(now: { Self.wednesday }).schoolToday == Self.kst(2026, 10, 7))
        #expect(MockStore(now: { Self.saturday }).schoolToday == Self.kst(2026, 10, 9))
    }

    @Test func weekCardMarksTodayAndApprovedDays() async throws {
        let store = MockStore(homeScenario: .notSubmitted, now: { Self.wednesday })
        let week = try #require(activeCleaning(try await fetchHome(store))?.week)
        let records = try await fetchMonth(store, YearMonth(year: 2026, month: 10)).records

        #expect(week.days.map(\.weekday) == [2, 3, 4, 5, 6])
        #expect(week.days.first(where: \.isToday)?.weekday == 4)
        let approvedDays = Set(records.filter { $0.result == .approved }.map { MockStore.calendar.component(.weekday, from: $0.date) })
        #expect(week.days.filter(\.isCompleted).map(\.weekday) == [2, 3].filter { approvedDays.contains($0) })
    }

    @Test func weekendHomeShowsFridayAsToday() async throws {
        let store = MockStore(now: { Self.saturday })
        let week = try #require(activeCleaning(try await fetchHome(store))?.week)

        #expect(week.days.first(where: \.isToday)?.weekday == 6)
    }

    // MARK: - 홈 · 기록 · 마이페이지

    @Test func homeRecentRecordsComeFromActivityRecords() async throws {
        let store = MockStore(now: { Self.wednesday })
        let recent = try #require(activeCleaning(try await fetchHome(store))?.recentRecords)
        let october = try await fetchMonth(store, YearMonth(year: 2026, month: 10)).records
        let september = try await fetchMonth(store, YearMonth(year: 2026, month: 9)).records
        let submittedBeforeToday = (october + september).filter { $0.result != .notSubmitted && $0.date < store.schoolToday }

        #expect(recent.count == 3)
        #expect(recent.map(\.id) == submittedBeforeToday.prefix(3).map(\.id))
        #expect(recent.map(\.date) == submittedBeforeToday.prefix(3).map(\.date))
        // Figma `02 홈` 최근 기록처럼 승인 · 승인 · 반려.
        #expect(recent.map(\.result) == [.approved(earnedMinutes: 10), .approved(earnedMinutes: 10), .rejected])
    }

    @Test func myPageMonthlyTotalsMatchActivityRecords() async throws {
        let store = MockStore(now: { Self.wednesday })
        let month = try await fetchMonth(store, YearMonth(year: 2026, month: 10))
        let summary = try await MockMyPageRepository(store: store, delay: .zero).fetchMyPage()

        #expect(summary.monthlyApprovedCount == month.count(of: .approved))
        #expect(summary.monthlyActivityMinutes == month.totalMinutes)
        #expect(summary.monthlyApprovedCount > 0)
        #expect(summary.hasApplied)
        #expect(summary.cleaningAreaName == MockHomeRepository.Fixture.area)
    }

    @Test func recordsOnlyInCurrentAndPreviousMonth() async throws {
        let store = MockStore(now: { Self.wednesday })

        #expect(try await fetchMonth(store, YearMonth(year: 2026, month: 8)).records.isEmpty)
        #expect(try await fetchMonth(store, YearMonth(year: 2026, month: 9)).records.count == 22)
        // 오늘은 아직 내지 않아 기록이 없다(10월 1·2·5·6일).
        #expect(try await fetchMonth(store, YearMonth(year: 2026, month: 10)).records.map(\.date) == [6, 5, 2, 1].map { Self.kst(2026, 10, $0) })
    }

    // MARK: - 청소 인증 제출

    @Test func submittedVerificationShowsOnHomeRecordsAndResult() async throws {
        let store = MockStore(now: { Self.wednesday })
        let verification = MockVerificationRepository(delay: .zero, now: { Self.wednesday }, store: store)
        let photo = VerificationPhoto(id: UUID(), jpegData: Data(), capturedAt: Self.wednesday)

        _ = try await verification.submit(photo)

        let today = try #require(activeCleaning(try await fetchHome(store))?.today)
        #expect(today.verification == .aiReviewing(submittedAt: Self.wednesday))
        #expect(today.submission == TodaySubmission(id: "verification-20261007", submittedAt: Self.wednesday))
        let todayRecord = try await fetchMonth(store, YearMonth(year: 2026, month: 10)).records.first
        #expect(todayRecord?.date == Self.kst(2026, 10, 7))
        #expect(todayRecord?.result == .reviewing)
        let result = try await MockVerificationResultRepository.matchingOtherMocks(delay: .zero, store: store).fetchResult(id: "verification-20261007")
        #expect(result.status == .processing)
        #expect(result.submittedAt == Self.wednesday)
        // 새 인증 화면(새 저장소)도 이미 제출한 것으로 본다.
        let session = try await MockVerificationRepository(delay: .zero, now: { Self.wednesday }, store: store).fetchSession()
        #expect(session.availability == .alreadySubmitted(submittedAt: Self.wednesday, status: .processing))
    }

    // MARK: - 모집

    @Test func awaitingAssignmentHomeHasApplication() async throws {
        let store = MockStore(homeScenario: .awaitingAssignment, now: { Self.wednesday })
        let application = try await MockRecruitmentRepository(delay: .zero, store: store).fetchMyApplication()

        #expect(application?.order == 4)
        #expect(application?.isAreaAssigned == false)
    }

    @Test func applyingMovesHomeToAwaitingAssignment() async throws {
        let store = MockStore(homeScenario: .recruiting, now: { Self.wednesday })
        let recruitment = MockRecruitmentRepository(delay: .zero, store: store)
        #expect(try await recruitment.fetchMyApplication() == nil)

        let application = try await recruitment.apply(motivation: "깨끗한 학교")

        #expect(try await fetchHome(store).status == .awaitingAssignment)
        #expect(try await MockRecruitmentRepository(delay: .zero, store: store).fetchMyApplication() == application)
        #expect(application.appliedAt == Self.wednesday)
        #expect(try await MockMyPageRepository(store: store, delay: .zero).fetchMyPage().hasApplied)
    }

    @Test func openRecruitmentPeriodContainsToday() async throws {
        let detail = try #require(try await MockRecruitmentRepository(delay: .zero, store: MockStore(homeScenario: .recruiting, now: { Self.wednesday })).fetchRecruitment())

        #expect(detail.startDate <= Self.wednesday)
        #expect(Self.wednesday <= detail.endDate)
        #expect(detail.status == .open)
    }

    @Test(arguments: [MockRecruitmentRepository.Scenario.upcoming, .ended])
    func otherPhasesKeepTheirPeriod(_ scenario: MockRecruitmentRepository.Scenario) async throws {
        let store = MockStore(homeScenario: .recruiting, now: { Self.wednesday })
        let detail = try #require(try await MockRecruitmentRepository(scenario: scenario, delay: .zero, store: store).fetchRecruitment())

        if scenario == .upcoming {
            #expect(detail.startDate > Self.wednesday)
            #expect(detail.status == .upcoming)
        } else {
            #expect(detail.endDate < Self.wednesday)
            #expect(detail.status == .ended)
        }
    }

    // MARK: - 이의신청

    @Test func appealTargetIsRejectedRecord() async throws {
        let store = MockStore(now: { Self.wednesday })
        let records = try await fetchMonth(store, YearMonth(year: 2026, month: 10)).records
            + fetchMonth(store, YearMonth(year: 2026, month: 9)).records
        let rejected = try #require(records.first { $0.result == .rejected })

        #expect(store.appealTarget.verificationID == rejected.verificationID)
        #expect(store.appealTarget.verifiedAt == rejected.submittedAt)
        let appeals = try await MockAppealRepository(delay: .zero, store: store).fetchAppeals()
        #expect(appeals.map(\.status) == [.reviewing, .rejected, .approved])
        #expect(appeals.filter { $0.verificationID == rejected.verificationID }.map(\.verifiedAt) == [rejected.submittedAt])
        // 검토 중인 이의신청은 다시 이의신청할 수 있는 반려와 다른 반려 기록에 있다.
        let pending = try #require(records.first { $0.verificationID == appeals.first?.verificationID })
        #expect(pending.result == .rejected)
        #expect(pending.verificationID != rejected.verificationID)
        #expect(appeals.first?.verifiedAt == pending.submittedAt)
        let appealApproved = try #require(records.first { $0.isAppealApproved })
        #expect(appeals.last?.verificationID == appealApproved.verificationID)
    }

    @Test func appealOnPendingVerificationIsNotReceivedAgain() async throws {
        let store = MockStore(now: { Self.wednesday })
        let repository = MockAppealRepository(delay: .zero, store: store)
        let pending = try #require(try await repository.fetchAppeals().first { $0.status == .reviewing })
        let draft = AppealDraft(requestID: "request-1", verificationID: pending.verificationID, message: "다시 봐 주세요", photos: [])

        await #expect(throws: AppealError.alreadyPending(pending)) {
            try await repository.submitAppeal(draft)
        }
        #expect(try await repository.fetchAppeals().count == 3)
    }

    @Test func appealHistoryIsSameEveryRun() async throws {
        let first = try await MockAppealRepository(delay: .zero, store: MockStore(now: { Self.wednesday })).fetchAppeals()
        let second = try await MockAppealRepository(delay: .zero, store: MockStore(now: { Self.wednesday })).fetchAppeals()

        #expect(first == second)
        #expect(first.filter { $0.status == .reviewing }.count == 1)
    }

    @Test func submittedAppealKeepsTargetDateAndShowsInHistory() async throws {
        let store = MockStore(homeScenario: .rejected, now: { Self.wednesday })
        let todayID = store.todayVerificationID
        let draft = AppealDraft(requestID: "request-1", verificationID: todayID, message: "다시 봐 주세요", photos: [])

        let appeal = try await MockAppealRepository(delay: .zero, store: store).submitAppeal(draft)

        #expect(appeal.verifiedAt == Self.kst(2026, 10, 7, 8, 4))
        #expect(appeal.round == 1)
        let history = try await MockAppealRepository(delay: .zero, store: store).fetchAppeals()
        #expect(history.first == appeal)
        #expect(history.count == 4)
    }
}
