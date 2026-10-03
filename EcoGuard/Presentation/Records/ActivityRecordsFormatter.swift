import Foundation

/// 활동 기록 목록의 주 묶음. 기록과 휴일 안내를 날짜 최신순으로 섞는다.
struct ActivityWeekSection: Equatable, Identifiable {
    enum Item: Equatable, Identifiable {
        case record(ActivityRecord)
        case holiday(HolidayPeriod)

        var id: String {
            switch self {
            case .record(let record): record.id
            case .holiday(let holiday): "holiday-\(holiday.start.timeIntervalSinceReferenceDate)"
            }
        }

        fileprivate var date: Date {
            switch self {
            case .record(let record): record.date
            case .holiday(let holiday): holiday.start
            }
        }
    }

    /// 오늘이 속한 주 = 0, 지난주 = 1.
    let weeksAgo: Int
    let items: [Item]

    var id: Int { weeksAgo }
}

/// 활동 기록 화면 표시 문자열과 주 묶음. 날짜는 학교 기준이라 기기 시간대와 관계없이 KST, 주는 월요일에 시작한다.
enum ActivityRecordsFormatter {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HomeFormatter.timeZone
        calendar.firstWeekday = 2
        return calendar
    }()

    private static let locale = Locale(identifier: "ko_KR")

    /// 기록·휴일을 `today`(KST) 기준 몇 주 전인지로 묶는다. 최근 주가 먼저 온다.
    static func sections(for month: ActivityMonth, today: Date) -> [ActivityWeekSection] {
        let items = month.records.map(ActivityWeekSection.Item.record) + month.holidays.map(ActivityWeekSection.Item.holiday)
        let grouped = Dictionary(grouping: items) { weeksAgo(of: $0.date, today: today) }
        return grouped.keys.sorted().map { weeksAgo in
            ActivityWeekSection(weeksAgo: weeksAgo, items: (grouped[weeksAgo] ?? []).sorted { $0.date > $1.date })
        }
    }

    /// 0 → "이번 주", 1 → "지난주", 2 → "2주 전". 오늘 이후 날짜는 이번 주로 본다.
    static func weeksAgo(of date: Date, today: Date) -> Int {
        guard
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
            let week = calendar.dateInterval(of: .weekOfYear, for: date)?.start,
            let days = calendar.dateComponents([.day], from: week, to: thisWeek).day
        else { return 0 }
        return max(0, days / 7)
    }

    static func weekTitle(weeksAgo: Int) -> String {
        switch weeksAgo {
        case 0: String(localized: "이번 주")
        case 1: String(localized: "지난주")
        default: String(localized: "\(weeksAgo)주 전")
        }
    }

    /// "2026년 9월"
    static func month(_ month: YearMonth) -> String {
        String(localized: "\(String(month.year))년 \(month.month)월")
    }

    /// "70분"
    static func minutes(_ minutes: Int) -> String {
        String(localized: "\(minutes)분")
    }

    /// "7회"
    static func count(_ count: Int) -> String {
        String(localized: "\(count)회")
    }

    /// "9월 29일(화)"
    static func recordDate(_ date: Date) -> String {
        formatter("M월 d일(E)").string(from: date)
    }

    /// 결과별 보조줄. "본관 2층 복도 A · 08:04", "08:05 · +10분 · 이의신청 승인", "본관 2층 복도 A · 인증하지 않았어요".
    static func detail(_ record: ActivityRecord) -> String {
        let time = record.submittedAt.map(HomeFormatter.clockTime)
        let parts: [String?] = switch record.result {
        case .reviewing, .rejected:
            [record.area, time]
        case .approved:
            [time, String(localized: "+\(record.earnedMinutes)분"), record.isAppealApproved ? String(localized: "이의신청 승인") : nil]
        case .notSubmitted:
            [record.area, String(localized: "인증하지 않았어요")]
        }
        return parts.compactMap(\.self).joined(separator: " · ")
    }

    /// "9월 24–25일 · 휴일로 청소하지 않아요". 하루면 "9월 24일", 달이 바뀌면 "9월 30일–10월 1일".
    static func holiday(_ holiday: HolidayPeriod) -> String {
        let start = calendar.dateComponents([.month, .day], from: holiday.start)
        let end = calendar.dateComponents([.month, .day], from: holiday.end)
        let range: String
        if start == end {
            range = formatter("M월 d일").string(from: holiday.start)
        } else if start.month == end.month {
            range = "\(formatter("M월 d").string(from: holiday.start))–\(formatter("d일").string(from: holiday.end))"
        } else {
            range = "\(formatter("M월 d일").string(from: holiday.start))–\(formatter("M월 d일").string(from: holiday.end))"
        }
        return String(localized: "\(range) · 휴일로 청소하지 않아요")
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}
