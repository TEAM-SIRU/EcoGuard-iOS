import Foundation

/// 서버(Spring `LocalDate`·`LocalDateTime`) 날짜 문자열. 시간대 표기가 없어 KST로 읽는다.
nonisolated enum ServerDate {
    static let timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current

    /// `yyyy-MM-dd`. 그날 00:00(KST).
    static func date(_ string: String) -> Date? {
        dateTime(string + "T00:00:00")
    }

    /// `yyyy-MM-dd'T'HH:mm:ss`. 초 뒤 소수점(`.SSSSSS`)은 버린다.
    static func dateTime(_ string: String) -> Date? {
        let parts = string.split(separator: "T", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let day = parts[0].split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
        let wholeSeconds = parts[1].split(separator: ".", maxSplits: 1).first ?? ""
        let time = wholeSeconds.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        guard day.count == 3, (2...3).contains(time.count),
              let year = day[0], let month = day[1], let dayOfMonth = day[2],
              let hour = time[0], let minute = time[1]
        else { return nil }
        let second = time.count == 3 ? time[2] : 0
        guard let second else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: dayOfMonth, hour: hour, minute: minute, second: second)
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }
}
