import Foundation
import Testing
@testable import EcoGuard

@Suite(.serialized)
@MainActor
struct ActivityRecordsFormatterTests {
    private func date(month: Int = 9, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private func record(_ result: ActivityRecord.Result, submittedAt: Date?, earnedMinutes: Int = 0, isAppealApproved: Bool = false) -> ActivityRecord {
        ActivityRecord(
            id: "r",
            date: date(day: 29),
            area: "본관 2층 복도 A",
            result: result,
            submittedAt: submittedAt,
            earnedMinutes: earnedMinutes,
            isAppealApproved: isAppealApproved
        )
    }

    private var figmaMonth: ActivityMonth {
        ActivityMonth(
            month: MockActivityRepository.Fixture.month,
            records: MockActivityRepository.Fixture.records,
            holidays: MockActivityRepository.Fixture.holidays
        )
    }

    /// 섹션마다 (주 전, 항목 id) 목록.
    private func layout(today: Date) -> [(Int, [String])] {
        ActivityRecordsFormatter.sections(for: figmaMonth, today: today).map { ($0.weeksAgo, $0.items.map(\.id)) }
    }

    @Test func sectionsMatchFigma() {
        let sections = layout(today: MockActivityRepository.Fixture.today)
        let holidayID = ActivityWeekSection.Item.holiday(MockActivityRepository.Fixture.holidays[0]).id

        #expect(sections.map(\.0) == [0, 1, 2])
        #expect(sections[0].1 == ["record-0929", "record-0928"])
        #expect(sections[1].1 == [holidayID, "record-0923", "record-0922", "record-0921"])
        #expect(sections[2].1 == ["record-0918", "record-0917", "record-0916", "record-0915", "record-0914"])
    }

    @Test func weekStartsOnMondayInKST() {
        // 월요일 0시(KST)부터 새 주. 바로 전 일요일 밤은 지난주다.
        let monday = date(day: 28)
        #expect(ActivityRecordsFormatter.weeksAgo(of: date(day: 28), today: monday) == 0)
        #expect(ActivityRecordsFormatter.weeksAgo(of: date(day: 27, hour: 23, minute: 59), today: monday) == 1)
        // 일요일까지는 같은 주다.
        let sunday = date(month: 10, day: 4, hour: 23, minute: 59)
        #expect(ActivityRecordsFormatter.weeksAgo(of: date(day: 28), today: sunday) == 0)
        #expect(ActivityRecordsFormatter.weeksAgo(of: date(day: 14), today: sunday) == 2)
    }

    @Test func futureDateCountsAsThisWeek() {
        #expect(ActivityRecordsFormatter.weeksAgo(of: date(month: 10, day: 20), today: date(day: 29)) == 0)
    }

    @Test(arguments: ["America/Los_Angeles", "UTC", "Pacific/Kiritimati", "Asia/Seoul"])
    func sectionsIgnoreDeviceTimeZone(identifier: String) {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = TimeZone(identifier: identifier) ?? original
        // KST 월요일 00:30 = LA 일요일 오전. 기기 시간대로 주를 나누면 9/28 기록이 지난주로 밀린다.
        let today = date(day: 28, hour: 0, minute: 30)

        let sections = layout(today: today)

        #expect(sections.map(\.0) == [0, 1, 2])
        #expect(sections[0].1 == ["record-0929", "record-0928"])
        #expect(ActivityRecordsFormatter.recordDate(date(day: 28)) == "9월 28일(월)")
    }

    @Test(arguments: [(0, "이번 주"), (1, "지난주"), (2, "2주 전"), (5, "5주 전")])
    func weekTitle(weeksAgo: Int, expected: String) {
        #expect(ActivityRecordsFormatter.weekTitle(weeksAgo: weeksAgo) == expected)
    }

    @Test func monthAndCountsMatchFigma() {
        #expect(ActivityRecordsFormatter.month(YearMonth(year: 2026, month: 9)) == "2026년 9월")
        #expect(ActivityRecordsFormatter.minutes(70) == "70분")
        #expect(ActivityRecordsFormatter.count(7) == "7회")
        #expect(ActivityRecordsFormatter.recordDate(date(day: 29)) == "9월 29일(화)")
    }

    @Test func monthCopyNamesMonthUnlessCurrent() {
        let current = YearMonth(year: 2026, month: 10)

        #expect(ActivityRecordsFormatter.totalTitle(current, current: current) == "이번 달 활동 시간")
        #expect(ActivityRecordsFormatter.emptyTitle(current, current: current) == "이번 달 기록이 아직 없어요")
        #expect(ActivityRecordsFormatter.totalTitle(YearMonth(year: 2026, month: 9), current: current) == "9월 활동 시간")
        #expect(ActivityRecordsFormatter.emptyTitle(YearMonth(year: 2026, month: 9), current: current) == "9월 기록이 아직 없어요")
        #expect(ActivityRecordsFormatter.totalTitle(YearMonth(year: 2025, month: 12), current: current) == "2025년 12월 활동 시간")
    }

    @Test func detailPerResultMatchesFigma() {
        let submitted = date(day: 29, hour: 8, minute: 4)

        #expect(ActivityRecordsFormatter.detail(record(.reviewing, submittedAt: submitted)) == "본관 2층 복도 A · 08:04")
        #expect(ActivityRecordsFormatter.detail(record(.rejected, submittedAt: submitted)) == "본관 2층 복도 A · 08:04")
        #expect(ActivityRecordsFormatter.detail(record(.approved, submittedAt: submitted, earnedMinutes: 10)) == "08:04 · +10분")
        #expect(
            ActivityRecordsFormatter.detail(record(.approved, submittedAt: submitted, earnedMinutes: 10, isAppealApproved: true))
                == "08:04 · +10분 · 이의신청 승인"
        )
        #expect(ActivityRecordsFormatter.detail(record(.notSubmitted, submittedAt: nil)) == "본관 2층 복도 A · 인증하지 않았어요")
    }

    @Test func holidayRange() {
        let suffix = " · 휴일로 청소하지 않아요"
        #expect(ActivityRecordsFormatter.holiday(HolidayPeriod(start: date(day: 24), end: date(day: 25))) == "9월 24–25일" + suffix)
        #expect(ActivityRecordsFormatter.holiday(HolidayPeriod(start: date(day: 24), end: date(day: 24))) == "9월 24일" + suffix)
        #expect(
            ActivityRecordsFormatter.holiday(HolidayPeriod(start: date(day: 30), end: date(month: 10, day: 2)))
                == "9월 30일–10월 2일" + suffix
        )
    }
}
