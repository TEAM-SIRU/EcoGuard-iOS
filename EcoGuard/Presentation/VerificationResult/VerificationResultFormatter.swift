import Foundation

/// 인증 결과 화면 날짜 문자열. 학교 기준 시각이라 `HomeFormatter`와 같이 KST로 고정한다.
enum VerificationResultFormatter {
    /// 오늘이면 "오늘 08:04", 아니면 "9월 29일(화) 08:04".
    static func submittedAt(_ date: Date, now: Date) -> String {
        isSameDay(date, now) ? "오늘 \(HomeFormatter.clockTime(date))" : HomeFormatter.recordDate(date)
    }

    /// "9월 29일(화)"
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = calendar
        formatter.timeZone = HomeFormatter.timeZone
        formatter.dateFormat = "M월 d일(E)"
        return formatter.string(from: date)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = HomeFormatter.timeZone
        return calendar
    }

    private static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
