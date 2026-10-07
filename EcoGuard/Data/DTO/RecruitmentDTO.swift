/// `GET /recruitments/current`. 날짜는 시간대 없는 서버 시각(KST) 문자열이다.
nonisolated struct CurrentRecruitmentResponseDTO: Decodable, Sendable {
    struct Period: Decodable, Sendable {
        let start: String
        let end: String
    }

    enum PeriodStatus: String, Decodable, Sendable {
        case upcoming = "UPCOMING"
        case open = "OPEN"
        case closed = "CLOSED"
    }

    /// 청소 활동 시간(하루 중). 서버 `LocalTime`이라 `"07:20:00"`. 모집에 정하지 않았으면 서버가 07:20~08:10으로 준다.
    struct ActivityTime: Decodable, Sendable {
        let start: String
        let end: String
    }

    let recruitmentId: Int64
    /// `"2026-2"`(연도-학기). `ServerSemester`로 읽는다.
    let semester: String
    let grade: Int
    let classNo: Int
    let period: Period
    let activityTime: ActivityTime
    let periodStatus: PeriodStatus
    let maxCount: Int
    let currentApplicants: Int
    let isFull: Bool
    let alreadyApplied: Bool
}

nonisolated struct ApplyRequestDTO: Encodable, Sendable {
    let motivation: String
}

/// 서버 `ApplicationStatus`. 신청하면 바로 `APPROVED`다(서버 #16에서 교사 확정 제거).
/// `PENDING`·`REJECTED`는 서버가 더 만들지 않지만 열거형과 이전 데이터에 남아 있어 받는다.
nonisolated enum ApplicationStatusDTO: String, Decodable, Sendable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
}

/// `POST /recruitments/{id}/applications` 201.
nonisolated struct ApplyResponseDTO: Decodable, Sendable {
    let applicationId: Int64
    let status: ApplicationStatusDTO
    let order: Int
    let studentNumber: String?
    let name: String
    /// 신청 시각. `2026-09-01T08:00:00`
    let appliedAt: String
}

/// `GET /applications/me`. 공고와 상관없이 가장 최근 신청이다.
nonisolated struct ApplicationStatusResponseDTO: Decodable, Sendable {
    /// 이 신청의 공고. 현재 공고의 신청인지 이것으로 본다.
    let recruitmentId: Int64
    let status: ApplicationStatusDTO
    let order: Int
    /// 신청 시각. `2026-09-01T08:00:00`
    let appliedAt: String
    /// 승인됐지만 아직 청소 구역이 배정되지 않았다. 승인이 아니면(`PENDING`·`REJECTED`) false다.
    let waitingForAssignment: Bool
}
