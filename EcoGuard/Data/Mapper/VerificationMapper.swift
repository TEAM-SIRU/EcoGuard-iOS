import Foundation

/// 승인된 인증에 더하는 봉사 시간. 서버 `AiReviewService.VERIFICATION_MINUTES`(응답에는 없다).
private nonisolated let approvedVerificationMinutes = 10

nonisolated extension VerificationStatusDTO {
    var status: VerificationResult.Status {
        switch self {
        case .processing: .processing
        case .approved: .approved
        case .rejected: .rejected
        case .manualReview: .manualReview
        }
    }
}

nonisolated extension VerificationResult.RejectionReason {
    /// 서버는 AI가 지적한 사유를 목록으로만 준다. 첫 사유를 제목으로, 나머지를 줄바꿈으로 이어 안내로 쓴다.
    init?(failReasons: [String]?) {
        let reasons = (failReasons ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let title = reasons.first else { return nil }
        let rest = reasons.dropFirst()
        self.init(title: title, guide: rest.isEmpty ? nil : rest.joined(separator: "\n"))
    }
}

nonisolated extension MyVerificationResponseDTO {
    /// 검수 상태와 사유는 `review`(인증 한 건 조회)를 쓴다. 목록보다 나중에 받았을 수 있어 더 최신이다.
    /// 제출 시각은 서버가 날짜만 주므로 그날 00:00(KST)이다.
    func result(review: ReviewResultResponseDTO, baseURL: URL) throws -> VerificationResult {
        guard let submittedAt = ServerDate.date(date) else { throw APIError.decoding }
        let status = review.status.status
        return VerificationResult(
            id: String(verificationId),
            submittedAt: submittedAt,
            area: areaName,
            status: status,
            rejectionReason: status == .rejected ? VerificationResult.RejectionReason(failReasons: review.failReasons) : nil,
            earnedMinutes: status == .approved ? approvedVerificationMinutes : 0,
            photoURL: URL(string: photoUrl, relativeTo: baseURL)?.absoluteURL,
            isSubmittedTimeKnown: false
        )
    }
}
