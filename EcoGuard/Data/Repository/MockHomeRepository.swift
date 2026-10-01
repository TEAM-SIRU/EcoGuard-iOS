import Foundation

/// 서버 연동 전까지 쓰는 Mock. 고른 상태(Figma `02 홈` 프레임)의 데이터를 지연 후 돌려준다.
final class MockHomeRepository: HomeRepository {
    enum Scenario: CaseIterable {
        case notSubmitted
        case aiReviewing
        case approved
        case rejected
        case teacherReviewing
        case notOpenYet
        case recruiting
        case awaitingAssignment
        case excluded
        case failure
    }

    struct FetchFailedError: Error {}

    private var scenarios: [Scenario]
    private let delay: Duration
    private let now: () -> Date
    private var dismissedNoticeIDs: Set<String> = []
    private(set) var fetchCallCount = 0
    private(set) var dismissedNoticeIDHistory: [String] = []

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1), now: @escaping () -> Date = Date.init) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
        self.now = now
    }

    convenience init(scenario: Scenario = .notSubmitted, delay: Duration = .seconds(1), now: @escaping () -> Date = Date.init) {
        self.init(scenarios: [scenario], delay: delay, now: now)
    }

    func fetchHome() async throws -> HomeSummary {
        fetchCallCount += 1
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        guard let summary = Fixture.summary(for: scenario, now: now()) else {
            throw FetchFailedError()
        }
        guard let notice = summary.notice, !dismissedNoticeIDs.contains(notice.id) else {
            return summary.removingNotice()
        }
        return summary
    }

    func dismissNotice(id: String) async {
        dismissedNoticeIDs.insert(id)
        dismissedNoticeIDHistory.append(id)
    }
}

extension MockHomeRepository {
    /// Figma `02 홈` 프레임에 적힌 값. 오늘은 2026-09-29(화)로 둔다. 날짜는 학교 시간대(KST) 기준이다.
    enum Fixture {
        static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            return calendar
        }()

        static let area = "본관 2층 복도 A"
        static let window = CleaningWindow(startMinute: 8 * 60, endMinute: 8 * 60 + 10)
        /// Figma `인증 마감까지 05:32`.
        static let remainingUntilDeadline: TimeInterval = 5 * 60 + 32

        static let notice = Notice(
            id: "notice-2026-09",
            title: "9월 환경지킴이 활동 안내",
            body: "매일 **08:00 – 08:10**에 청소하고 **사진 1장**으로 인증해 주세요.",
            publishedAt: date(month: 9, day: 1),
            isNew: true
        )

        static let recentRecords = [
            CleaningRecord(id: "record-0928", cleanedAt: date(month: 9, day: 28, hour: 8, minute: 5), area: area, result: .approved(earnedMinutes: 10)),
            CleaningRecord(id: "record-0923", cleanedAt: date(month: 9, day: 23, hour: 8, minute: 9), area: area, result: .approved(earnedMinutes: 10)),
            CleaningRecord(id: "record-0922", cleanedAt: date(month: 9, day: 22, hour: 8, minute: 4), area: area, result: .rejected)
        ]

        static let submittedAt = date(month: 9, day: 29, hour: 8, minute: 4)

        static func summary(for scenario: Scenario, now: Date) -> HomeSummary? {
            switch scenario {
            case .notSubmitted:
                active(.open(deadline: now.addingTimeInterval(remainingUntilDeadline)), notice: notice)
            case .aiReviewing:
                active(.aiReviewing(submittedAt: submittedAt))
            case .approved:
                active(.approved(earnedMinutes: 10), isTodayCompleted: true)
            case .rejected:
                active(.rejected(reason: "사진에 청소 구역이 잘 보이지 않아요"))
            case .teacherReviewing:
                active(.teacherReviewing(submittedAt: submittedAt))
            case .notOpenYet:
                active(.notOpenYet(opensAt: opensAt(onDayOf: now)))
            case .recruiting:
                HomeSummary(
                    status: .recruiting(Recruitment(semester: 2, capacityPerClass: 6, className: "2학년 3반", appliedCount: 4)),
                    notice: notice
                )
            case .awaitingAssignment:
                HomeSummary(status: .awaitingAssignment, notice: notice)
            case .excluded:
                HomeSummary(status: .excluded(reason: "본인 요청으로 활동을 중단했어요."), notice: nil)
            case .failure:
                nil
            }
        }

        private static func active(_ verification: TodayVerification, isTodayCompleted: Bool = false, notice: Notice? = nil) -> HomeSummary {
            let week = WeeklyCleaning(days: [
                .init(weekday: 2, isToday: false, isCompleted: true),
                .init(weekday: 3, isToday: true, isCompleted: isTodayCompleted),
                .init(weekday: 4, isToday: false, isCompleted: false),
                .init(weekday: 5, isToday: false, isCompleted: false),
                .init(weekday: 6, isToday: false, isCompleted: false)
            ])
            let cleaning = ActiveCleaning(
                today: TodayCleaning(area: area, window: window, verification: verification),
                week: week,
                recentRecords: recentRecords
            )
            return HomeSummary(status: .active(cleaning), notice: notice)
        }

        /// `now`가 속한 날(KST)의 인증 시작 시각.
        static func opensAt(onDayOf now: Date) -> Date {
            calendar.date(byAdding: .minute, value: window.startMinute, to: calendar.startOfDay(for: now)) ?? now
        }

        private static func date(month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
            let components = DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
            return calendar.date(from: components) ?? .distantPast
        }
    }
}
