import Foundation

/// 활동 기록 한 건(하루 청소 한 번).
struct ActivityRecord: Equatable, Identifiable {
    enum Result: Equatable {
        case reviewing
        case approved
        case rejected
        case notSubmitted
    }

    /// 승인 1회에 적립되는 활동 시간.
    static let minutesPerApproval = 10

    let id: String
    /// 청소한 날. 학교 시간대(KST) 기준 그날 0시.
    let date: Date
    let area: String
    let result: Result
    /// 사진을 낸 시각. 미제출이면 nil.
    let submittedAt: Date?
    /// 그날 제출한 인증. 인증 상세(결과) 화면을 열 때 쓴다. 미제출이면 nil.
    let verificationID: String?
    /// 적립된 활동 시간(분). 승인일 때만 0보다 크다.
    let earnedMinutes: Int
    /// 반려 후 이의신청이 받아들여져 승인된 기록인지.
    let isAppealApproved: Bool
}

/// 휴일로 청소하지 않는 기간. 시작·끝 모두 포함하고 KST 기준 그날 0시다.
struct HolidayPeriod: Equatable {
    let start: Date
    let end: Date
}

/// 조회할 달.
struct YearMonth: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// 한 달 활동 기록.
struct ActivityMonth: Equatable {
    let month: YearMonth
    /// 최신순.
    let records: [ActivityRecord]
    let holidays: [HolidayPeriod]

    var totalMinutes: Int {
        records.reduce(0) { $0 + $1.earnedMinutes }
    }

    func count(of result: ActivityRecord.Result) -> Int {
        records.filter { $0.result == result }.count
    }
}
