nonisolated extension MyActivityResponseDTO {
    /// 휴일은 서버가 아직 내려주지 않아 비워 둔다.
    func toDomain() throws -> ActivityMonth {
        ActivityMonth(
            month: YearMonth(year: year, month: month),
            records: try records.compactMap { try $0.toDomain() },
            holidays: []
        )
    }
}

nonisolated extension ActivityRecordDTO {
    /// 아직 인증 시간이 지나지 않은 날과 알 수 없는 결과는 기록이 아니므로 nil.
    func toDomain() throws -> ActivityRecord? {
        guard let result = result.recordResult else { return nil }
        guard let day = ServerDate.day(date) else { throw APIError.decoding }
        return ActivityRecord(
            // 하루 한 건이라 날짜가 곧 식별자다.
            id: date,
            date: day,
            area: area,
            result: result,
            submittedAt: nil,
            verificationID: verificationId.map(String.init),
            earnedMinutes: minutes,
            // TODO: 서버가 이의신청 승인 여부를 내려주면 바꾼다.
            isAppealApproved: false
        )
    }
}

nonisolated extension ActivityResultDTO {
    var recordResult: ActivityRecord.Result? {
        switch self {
        case .approved: .approved
        case .rejected: .rejected
        case .processing, .manualReview: .reviewing
        case .notSubmitted: .notSubmitted
        case .upcoming, .unknown: nil
        }
    }
}
