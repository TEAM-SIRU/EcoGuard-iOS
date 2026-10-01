import Foundation

/// 모집·신청 화면 표시 문자열. 홈과 같이 ko_KR · KST로 고정한다.
enum RecruitmentFormatter {
    /// "9월 1일(화)"
    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = HomeFormatter.timeZone
        formatter.dateFormat = "M월 d일(E)"
        return formatter.string(from: date)
    }

    /// "9월 1일(화) – 9월 4일(금)"
    static func period(start: Date, end: Date) -> String {
        "\(day(start)) – \(day(end))"
    }

    /// "매일 08:00 – 08:10"
    static func activityTime(_ window: CleaningWindow) -> String {
        "매일 \(HomeFormatter.window(window))"
    }

    /// "9월 1일(화) 12:34"
    static func appliedAt(_ date: Date) -> String {
        HomeFormatter.recordDate(date)
    }
}
