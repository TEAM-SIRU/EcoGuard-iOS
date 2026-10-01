import Foundation

/// 오늘의 청소 카드.
struct TodayCleaning: Equatable {
    let area: String
    let window: CleaningWindow
    let verification: TodayVerification
}

/// 인증 가능 시간. 하루 기준 분(0시 = 0)으로 받는다. 예: 08:00 → 480.
struct CleaningWindow: Equatable {
    let startMinute: Int
    let endMinute: Int
}

/// 오늘 인증 상태. 인증 가능 여부는 클라이언트 시간이 아니라 서버가 내려준 값으로 판단한다.
enum TodayVerification: Equatable {
    /// 인증 시간 전.
    case notOpenYet
    /// 인증 가능. `deadline`까지 남은 시간은 표시용이다.
    case open(deadline: Date)
    case aiReviewing(submittedAt: Date)
    /// AI가 판단하기 어려워 선생님이 확인 중이다.
    case teacherReviewing(submittedAt: Date)
    case approved(earnedMinutes: Int)
    case rejected(reason: String)
}
