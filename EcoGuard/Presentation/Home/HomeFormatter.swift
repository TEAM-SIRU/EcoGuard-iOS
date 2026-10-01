import Foundation

/// 홈 화면 표시 문자열. 앱은 한국어만 지원해 ko_KR로 고정한다.
enum HomeFormatter {
    private static let locale = Locale(identifier: "ko_KR")

    /// 480 → "08:00"
    static func time(minuteOfDay: Int) -> String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    /// "08:00 – 08:10"
    static func window(_ window: CleaningWindow) -> String {
        "\(time(minuteOfDay: window.startMinute)) – \(time(minuteOfDay: window.endMinute))"
    }

    /// 남은 시간 "05:32". 지나면 "00:00".
    static func countdown(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.down)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    /// "9월 28일(월) 08:05"
    static func recordDate(_ date: Date) -> String {
        formatter("M월 d일(E) HH:mm").string(from: date)
    }

    /// "08:04". 오늘 카드는 오늘 제출분만 보여 주므로 날짜를 붙이지 않는다.
    static func clockTime(_ date: Date) -> String {
        formatter("HH:mm").string(from: date)
    }

    /// "2026. 09. 01"
    static func noticeDate(_ date: Date) -> String {
        formatter("yyyy. MM. dd").string(from: date)
    }

    /// `Calendar` 요일(일 = 1) → "월"
    static func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = formatter("E").veryShortWeekdaySymbols ?? []
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = format
        return formatter
    }
}
