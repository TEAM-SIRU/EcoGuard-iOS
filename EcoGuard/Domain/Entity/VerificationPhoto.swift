import Foundation

/// 업로드할 인증 사진. 같은 사진을 다시 보낼 때는 `id`를 그대로 써서 서버가 같은 제출로 알아보게 한다.
struct VerificationPhoto: Equatable {
    let id: UUID
    let jpegData: Data
    let capturedAt: Date
}

struct VerificationSubmission: Equatable {
    /// 서버가 붙인 인증 ID. 결과 조회·이의신청에 쓴다. Mock은 nil.
    var id: String?
    let submittedAt: Date

    init(id: String? = nil, submittedAt: Date) {
        self.id = id
        self.submittedAt = submittedAt
    }
}

enum VerificationError: Error, Equatable {
    /// 마감이 지나 새 사진을 받을 수 없다. 마감 전에 보내기 시작한 사진의 재시도는 해당하지 않는다.
    case deadlinePassed
    /// 오늘 다른 사진을 이미 제출했다. 서버가 제출 시각·검수 상태를 주지 않으면 nil이다.
    case alreadySubmitted(submittedAt: Date?, status: VerificationResult.Status?)
}
