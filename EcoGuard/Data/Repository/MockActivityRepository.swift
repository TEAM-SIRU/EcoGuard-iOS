import Foundation

/// 서버 연동 전까지 쓰는 Mock. 고른 상태(Figma `07 활동 기록` 프레임)의 데이터를 지연 후 돌려준다.
final class MockActivityRepository: ActivityRepository {
    enum Scenario: CaseIterable {
        /// 오늘 기준 이번 달·지난달에 기록이 있다. 2026년 9월은 Figma 기록 그대로, 그 밖의 달은 빈 달.
        case records
        case empty
        case failure
        /// URLSession 요청이 취소된 것처럼 `URLError.cancelled`를 던진다.
        case cancelledURL
    }

    struct FetchFailedError: Error {}

    private var scenarios: [Scenario]
    private let delay: Duration
    private let now: () -> Date
    private(set) var requestedMonths: [YearMonth] = []

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1), now: @escaping () -> Date = Date.init) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
        self.now = now
    }

    convenience init(scenario: Scenario = .records, delay: Duration = .seconds(1), now: @escaping () -> Date = Date.init) {
        self.init(scenarios: [scenario], delay: delay, now: now)
    }

    func fetchMonth(year: Int, month: Int) async throws -> ActivityMonth {
        let requested = YearMonth(year: year, month: month)
        requestedMonths.append(requested)
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        switch scenario {
        case .records where requested == Fixture.month:
            return ActivityMonth(month: requested, records: Fixture.records, holidays: Fixture.holidays)
        case .records where Fixture.recentMonths(now: now()).contains(requested):
            return ActivityMonth(month: requested, records: Fixture.generatedRecords(in: requested, now: now()), holidays: [])
        case .records, .empty:
            return ActivityMonth(month: requested, records: [], holidays: [])
        case .failure:
            throw FetchFailedError()
        case .cancelledURL:
            throw URLError(.cancelled)
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

        /// `now`(KST)가 속한 달과 그 전 달.
        static func recentMonths(now: Date) -> [YearMonth] {
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let year = components.year, let month = components.month else { return [] }
            let previous = month == 1 ? YearMonth(year: year - 1, month: 12) : YearMonth(year: year, month: month - 1)
            return [YearMonth(year: year, month: month), previous]
        }

        /// 서버 없이 앱을 돌려 볼 수 있게 `month`의 평일마다 기록을 만든다(오늘 이후는 없음, 최신순).
        /// 오늘은 검수 중, 나머지는 대부분 승인이고 7일·17일은 반려·미제출, 21일은 이의신청 승인이다.
        static func generatedRecords(in month: YearMonth, now: Date) -> [ActivityRecord] {
            let today = calendar.startOfDay(for: now)
            guard
                let first = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1)),
                let days = calendar.range(of: .day, in: .month, for: first)
            else { return [] }
            return days.reversed().compactMap { day -> ActivityRecord? in
                guard
                    let date = calendar.date(from: DateComponents(year: month.year, month: month.month, day: day)),
                    date <= today,
                    !calendar.isDateInWeekend(date)
                else { return nil }
                let result: ActivityRecord.Result = switch day {
                case _ where date == today: .reviewing
                case 7: .rejected
                case 17: .notSubmitted
                default: .approved
                }
                return ActivityRecord(
                    id: "record-\(month.year)-\(month.month)-\(day)",
                    date: date,
                    area: area,
                    result: result,
                    submittedAt: result == .notSubmitted ? nil : calendar.date(byAdding: .minute, value: 8 * 60 + day % 10, to: date),
                    verificationID: result == .notSubmitted ? nil : verificationID(year: month.year, month: month.month, day: day),
                    earnedMinutes: result == .approved ? ActivityRecord.minutesPerApproval : 0,
                    isAppealApproved: day == 21
                )
            }
        }

        /// 이 Mock이 내려 준 인증 ID의 결과 상태와 제출 시각. 인증 결과 Mock이 같은 상태의 결과를 돌려줄 때 쓴다.
        /// 이 Mock이 만든 ID가 아니면 nil.
        static func submittedRecord(verificationID: String, now: Date) -> (status: VerificationResult.Status, submittedAt: Date)? {
            let candidates = records + recentMonths(now: now).flatMap { generatedRecords(in: $0, now: now) }
            guard let record = candidates.first(where: { $0.verificationID == verificationID }), let submittedAt = record.submittedAt else { return nil }
            let status: VerificationResult.Status? = switch record.result {
            case .reviewing: .processing
            case .approved: .approved
            case .rejected: .rejected
            case .notSubmitted: nil
            }
            return status.map { ($0, submittedAt) }
        }

        /// 홈·청소 인증과 같은 `verification-YYYYMMDD` 체계.
        private static func verificationID(year: Int, month: Int, day: Int) -> String {
            String(format: "verification-%04d%02d%02d", year, month, day)
        }

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
                verificationID: time.map { _ in verificationID(year: month.year, month: month.month, day: day) },
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
