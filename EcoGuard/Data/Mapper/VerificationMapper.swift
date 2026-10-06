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
    func result(review: ReviewResultResponseDTO, baseURL: URL) throws -> VerificationResult {
        let submittedAt = try ServerDate.requiredDateTime(self.submittedAt)
        let status = review.status.status
        return VerificationResult(
            id: String(verificationId),
            submittedAt: submittedAt,
            area: areaName,
            status: status,
            rejectionReason: status == .rejected ? VerificationResult.RejectionReason(failReasons: review.failReasons) : nil,
            earnedMinutes: status == .approved ? approvedVerificationMinutes : 0,
            photoURL: URL(string: photoUrl, relativeTo: baseURL)?.absoluteURL
        )
    }
}

extension TodayVerificationResponseDTO {
    /// 마감은 서버 시각의 날짜와 `endTime`으로 만든다. 서버는 마감 시각까지 받는다.
    func session() throws -> VerificationSession {
        let serverNow = try ServerDate.requiredDateTime(serverTime)
        let day = serverTime.prefix { $0 != "T" }
        guard let startMinute = Self.minuteOfDay(startTime),
              let endMinute = Self.minuteOfDay(endTime),
              let deadline = ServerDate.dateTime("\(day)T\(endTime)")
        else { throw APIError.decoding }
        return VerificationSession(
            area: areaName,
            window: CleaningWindow(startMinute: startMinute, endMinute: endMinute),
            availability: availability(deadline: deadline),
            serverNow: serverNow
        )
    }

    private func availability(deadline: Date) -> VerificationAvailability {
        if submitted || unavailableReason == "ALREADY_SUBMITTED" {
            return .alreadySubmitted(
                submittedAt: submittedAt.flatMap(ServerDate.dateTime),
                status: status.flatMap(VerificationStatusDTO.init(rawValue:))?.status
            )
        }
        if canSubmit {
            return .open(deadline: deadline)
        }
        return switch unavailableReason {
        case "WEEKEND": .outsideWindow(.weekend)
        case "VACATION": .outsideWindow(.vacation)
        // BEFORE_START·AFTER_END. 모르는 사유도 인증 시간 아님으로 안내한다.
        default: .outsideWindow(.outsideHours)
        }
    }

    /// `HH:mm(:ss)` → 하루 기준 분.
    private static func minuteOfDay(_ time: String) -> Int? {
        let parts = time.split(separator: ":").map { Int($0) }
        guard (2...3).contains(parts.count), let hour = parts[0], let minute = parts[1] else { return nil }
        return hour * 60 + minute
    }
}
