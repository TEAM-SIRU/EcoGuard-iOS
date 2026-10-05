import Foundation

/// 제출한 청소 인증 한 건의 검수 결과.
struct VerificationResult: Equatable, Identifiable {
    /// 검수 상태. 서버 값(`PROCESSING` 등)을 rawValue로 둔다.
    enum Status: String, Equatable {
        /// AI 검수 중.
        case processing = "PROCESSING"
        case approved = "APPROVED"
        case rejected = "REJECTED"
        /// AI가 판단하지 못해 선생님이 직접 확인한다.
        case manualReview = "MANUAL_REVIEW"
    }

    /// 반려 사유. `guide`는 다시 찍을 때 참고할 안내다.
    struct RejectionReason: Equatable {
        let title: String
        let guide: String?
    }

    let id: String
    let submittedAt: Date
    let area: String
    let status: Status
    /// 반려일 때만 있다.
    let rejectionReason: RejectionReason?
    /// 활동 시간에 더한 분. 승인 전에는 0이다.
    let earnedMinutes: Int
    /// 제출한 사진 주소. 없으면 자리표시를 그린다.
    let photoURL: URL?
    /// 서버가 날짜만 주면 false이고 `submittedAt`은 그날 00:00이다. 화면은 날짜만 보여 준다.
    var isSubmittedTimeKnown = true
}
