import Foundation

/// 청소 인증 화면에 들어올 때 서버가 내려주는 오늘 인증 정보.
struct VerificationSession: Equatable {
    let area: String
    let window: CleaningWindow
    let availability: VerificationAvailability
}

/// 지금 인증 사진을 보낼 수 있는지. 클라이언트 시간이 아니라 서버가 내려준 값으로 판단한다.
enum VerificationAvailability: Equatable {
    /// 인증 가능. `deadline`은 서버가 정한 마감 시각으로, 남은 시간 표시와 마감 도달 처리에 쓴다.
    case open(deadline: Date)
    /// 인증 시간 밖이다.
    case outsideWindow
    /// 오늘 이미 제출했다. 하루 1번만 제출할 수 있다.
    case alreadySubmitted(submittedAt: Date)
}
