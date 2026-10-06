import Foundation

/// 청소 인증 화면에 들어올 때 서버가 내려주는 오늘 인증 정보.
struct VerificationSession: Equatable {
    let area: String
    let window: CleaningWindow
    let availability: VerificationAvailability
    /// 응답 시점의 서버 시각. 기기 시계가 틀려도 마감·남은 시간을 서버 기준으로 계산하는 데 쓴다.
    let serverNow: Date
}

/// 지금 인증 사진을 보낼 수 있는지. 클라이언트 시간이 아니라 서버가 내려준 값으로 판단한다.
enum VerificationAvailability: Equatable {
    /// 인증 가능. `deadline`은 서버가 정한 마감 시각으로, 남은 시간 표시와 마감 도달 처리에 쓴다.
    /// 마감 시각을 모르면 nil이고, 남은 시간을 보여 주지 않고 마감 판단은 제출 응답에 맡긴다.
    case open(deadline: Date?)
    /// 지금은 인증할 수 없다.
    case outsideWindow(VerificationClosedReason)
    /// 오늘 이미 제출했다. 하루 1번만 제출할 수 있다.
    /// 서버가 제출 시각·검수 상태를 주지 않으면 nil이다.
    case alreadySubmitted(submittedAt: Date?, status: VerificationResult.Status?)
}

/// 인증할 수 없는 이유. 주말·방학은 안내 화면 디자인 전이라 `인증 시간 아님` 시트에 문구만 바꿔 쓴다.
enum VerificationClosedReason: Equatable {
    /// 인증 시간 전이거나 지났다.
    case outsideHours
    case weekend
    case vacation
}

extension VerificationSession {
    /// 마감 전에 보내기 시작한 사진의 재시도를 마감 뒤에도 받아 주는 시간.
    /// 서버 `verification.late-retry-grace-minutes` 기본값 5분(응답에는 없다).
    static let lateRetryGrace: TimeInterval = 5 * 60
}
