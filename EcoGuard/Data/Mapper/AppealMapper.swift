import Foundation

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
    /// 선생님 답변은 반려일 때만 쓴다. 제목이 없으면 본문을 제목으로 쓴다.
    /// 사진 주소는 화면 표시용이라 읽지 못한 주소는 빼고, 적립 분이 없으면 0이다.
    func appeal(baseURL: URL) throws -> Appeal {
        guard let verifiedAt = ServerDate.date(verificationDate),
              let submittedAt = ServerDate.dateTime(createdAt)
        else { throw APIError.decoding }
        let status = status.status
        return Appeal(
            id: String(appealId),
            verificationID: String(verificationId),
            verifiedAt: verifiedAt,
            round: round,
            submittedAt: submittedAt,
            status: status,
            earnedMinutes: status == .approved ? awardedMinutes ?? 0 : 0,
            teacherReply: status == .rejected ? teacherReply : nil,
            photoURLs: (photoUrls ?? []).compactMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL },
            isVerifiedTimeKnown: false
        )
    }

    private var teacherReply: Appeal.TeacherReply? {
        let title = replyTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let body = reply?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        if let title {
            return Appeal.TeacherReply(title: title, message: body)
        }
        return body.map { Appeal.TeacherReply(title: $0, message: nil) }
    }
}

private nonisolated extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
