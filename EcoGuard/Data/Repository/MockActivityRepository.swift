import Foundation

/// 서버 연동 전까지 쓰는 Mock. 고른 상태(Figma `07 활동 기록` 프레임)의 데이터를 지연 후 돌려준다.
final class MockActivityRepository: ActivityRepository {
    enum Scenario: CaseIterable {
        /// 2026년 9월은 Figma 기록, 다른 달은 빈 달.
        case records
        case empty
        case failure
    }

    struct FetchFailedError: Error {}

    private var scenarios: [Scenario]
    private let delay: Duration
    private(set) var requestedMonths: [YearMonth] = []

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1)) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
    }

    convenience init(scenario: Scenario = .records, delay: Duration = .seconds(1)) {
        self.init(scenarios: [scenario], delay: delay)
    }

    func fetchMonth(year: Int, month: Int) async throws -> ActivityMonth {
        let requested = YearMonth(year: year, month: month)
        requestedMonths.append(requested)
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        switch scenario {
        case .records where requested == Fixture.month:
            return ActivityMonth(month: requested, records: Fixture.records, holidays: Fixture.holidays)
        case .records, .empty:
            return ActivityMonth(month: requested, records: [], holidays: [])
        case .failure:
            throw FetchFailedError()
        }
    }
}

extension MockActivityRepository {
    /// Figma `07 활동 기록` (240:3)에 적힌 값. 날짜는 학교 시간대(KST) 기준이다.
    enum Fixture {
        static let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
            return calendar
        }()

        static let month = YearMonth(year: 2026, month: 9)
        static let area = "본관 2층 복도 A"
        /// Figma 기준 오늘(2026-09-29 화) 오전 9시.
        static let today = date(day: 29, hour: 9)

        static let records = [
            record(day: 29, .reviewing, submittedAt: (8, 4)),
            record(day: 28, .approved, submittedAt: (8, 5)),
            record(day: 23, .approved, submittedAt: (8, 9)),
            record(day: 22, .rejected, submittedAt: (8, 4)),
            record(day: 21, .approved, submittedAt: (8, 7), isAppealApproved: true),
            record(day: 18, .approved, submittedAt: (8, 2)),
            record(day: 17, .notSubmitted, submittedAt: nil),
            record(day: 16, .approved, submittedAt: (8, 6)),
            record(day: 15, .approved, submittedAt: (8, 1)),
            record(day: 14, .approved, submittedAt: (8, 3))
        ]

        static let holidays = [HolidayPeriod(start: date(day: 24), end: date(day: 25))]

        private static func record(
            day: Int,
            _ result: ActivityRecord.Result,
            submittedAt time: (hour: Int, minute: Int)?,
            isAppealApproved: Bool = false
        ) -> ActivityRecord {
            ActivityRecord(
                id: "record-09\(day)",
                date: date(day: day),
                area: area,
                result: result,
                submittedAt: time.map { date(day: day, hour: $0.hour, minute: $0.minute) },
                earnedMinutes: result == .approved ? ActivityRecord.minutesPerApproval : 0,
                isAppealApproved: isAppealApproved
            )
        }

        private static func date(day: Int, hour: Int = 0, minute: Int = 0) -> Date {
            let components = DateComponents(year: month.year, month: month.month, day: day, hour: hour, minute: minute)
            return calendar.date(from: components) ?? .distantPast
        }
    }
}
