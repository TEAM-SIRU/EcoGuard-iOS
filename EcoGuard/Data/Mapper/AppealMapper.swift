import Foundation

/// 승인된 이의신청에 더하는 봉사 시간. 서버 `AppealService.APPEAL_APPROVED_MINUTES`(응답에는 없다).
private nonisolated let approvedAppealMinutes = 10

nonisolated extension AppealStatusDTO {
    var status: Appeal.Status {
        switch self {
        case .pending: .reviewing
        case .approved: .approved
        case .rejected: .rejected
        }
    }
}

nonisolated extension MyAppealResponseDTO {
    /// 서버는 대상 인증의 날짜만 주므로 `verifiedAt`은 그날 00:00(KST)이다.
    /// 선생님 답변은 문장 하나라 제목으로 쓴다. 이의신청 사진은 서버가 받지 않아 nil이다.
    var appeal: Appeal {
        get throws {
            guard let verifiedAt = ServerDate.date(verificationDate),
                  let submittedAt = ServerDate.dateTime(createdAt)
            else { throw APIError.decoding }
            let status = status.status
            let replyTitle = reply?.trimmingCharacters(in: .whitespacesAndNewlines)
            return Appeal(
                id: String(appealId),
                verificationID: String(verificationId),
                verifiedAt: verifiedAt,
                round: round,
                submittedAt: submittedAt,
                status: status,
                earnedMinutes: status == .approved ? approvedAppealMinutes : 0,
                teacherReply: status == .rejected && replyTitle?.isEmpty == false
                    ? Appeal.TeacherReply(title: replyTitle ?? "", message: nil)
                    : nil,
                photoURL: nil,
                isVerifiedTimeKnown: false
            )
        }
    }
}
