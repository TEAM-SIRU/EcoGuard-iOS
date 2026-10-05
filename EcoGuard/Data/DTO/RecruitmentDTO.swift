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

    let recruitmentId: Int64
    /// 서버가 형식을 정하지 않은 문자열이다(교사 웹 입력값). 예: "2", "2026-2".
    let semester: String
    let grade: Int
    let classNo: Int
    let period: Period
    let periodStatus: PeriodStatus
    let maxCount: Int
    let currentApplicants: Int
    let isFull: Bool
    let alreadyApplied: Bool
}

nonisolated struct ApplyRequestDTO: Encodable, Sendable {
    let motivation: String
}

/// 서버 `ApplicationStatus`. 신청하면 `PENDING`이고 선생님이 확정하면 `APPROVED`/`REJECTED`가 된다.
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
}

/// `GET /applications/me`.
nonisolated struct ApplicationStatusResponseDTO: Decodable, Sendable {
    let status: ApplicationStatusDTO
    let order: Int
    /// 승인됐지만 아직 청소 구역이 배정되지 않았다. 승인 전(`PENDING`)에는 false다.
    let waitingForAssignment: Bool
    /// 서버에 아직 없다(서버 요청). 내려오면 쓴다.
    let appliedAt: String?
}
