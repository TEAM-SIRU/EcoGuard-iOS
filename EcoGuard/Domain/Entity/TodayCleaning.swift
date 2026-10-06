import Foundation

/// 오늘의 청소 카드.
struct TodayCleaning: Equatable {
    let area: String
    let window: CleaningWindow
    let verification: TodayVerification
    /// 오늘 제출한 인증. 인증 결과·이의신청 화면을 열 때 쓴다. 제출 전이면 nil.
    let submission: TodaySubmission?
}

/// 오늘 제출한 인증 한 건.
struct TodaySubmission: Equatable {
    let id: String
    /// 서버가 제출 시각을 주지 않으면(현재 서버) 인증한 날 0시(KST).
    let submittedAt: Date
}

/// 인증 가능 시간. 하루 기준 분(0시 = 0)으로 받는다. 예: 08:00 → 480.
struct CleaningWindow: Equatable {
    let startMinute: Int
    let endMinute: Int
}

/// 오늘 인증 상태. 인증 가능 여부는 클라이언트 시간이 아니라 서버가 내려준 값으로 판단한다.
enum TodayVerification: Equatable {
    /// 인증 시간 전. `opensAt`에 다시 조회한다.
    case notOpenYet(opensAt: Date)
    /// 인증 가능. `deadline`까지 남은 시간은 표시용이고, 지나면 다시 조회한다.
    case open(deadline: Date)
    /// 방학이라 인증하지 않는다. 언제 끝나는지 서버가 주지 않아 다시 조회할 시각이 없다(앱 복귀·당겨서 새로고침으로 갱신).
    case vacation
    /// `submittedAt`은 서버가 제출 시각을 주지 않으면(현재 서버) nil.
    case aiReviewing(submittedAt: Date?)
    /// AI가 판단하기 어려워 선생님이 확인 중이다.
    case teacherReviewing(submittedAt: Date?)
    case approved(earnedMinutes: Int)
    case rejected(reason: String)

    /// 상태가 바뀌어 다시 조회해야 하는 시각.
    var nextRefreshDate: Date? {
        switch self {
        case .notOpenYet(let opensAt): opensAt
        case .open(let deadline): deadline
        case .vacation, .aiReviewing, .teacherReviewing, .approved, .rejected: nil
        }
    }

    /// 인증 버튼을 켤지. 서버가 `open`을 내려준 경우에만, 마감 전까지 켠다(클라이언트 시간은 UI 힌트로만 쓴다).
    func acceptsSubmission(at date: Date) -> Bool {
        guard case .open(let deadline) = self else { return false }
        return date < deadline
    }
}
