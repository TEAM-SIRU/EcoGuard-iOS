/// 홈·마이페이지를 만들 때 함께 읽는 다른 도메인 응답. 모집·공지·구역·인증 저장소의 DTO와 이름이 겹치지 않게 묶어 둔다.
/// 서버 계약: EcoGuard-Server `cleaningarea`, `verification`, `recruitment`, `notice`의 dto.
nonisolated enum HomeDTO {
    /// `GET /assignments/me`. 배정 전이면 404 `NO_ASSIGNMENT`.
    nonisolated struct Assignment: Decodable, Sendable {
        let areaId: Int64
        let areaName: String
        /// `07:20~08:10`. 없으면 서버 기본 시간을 쓴다.
        let cleanTime: String?
    }

    nonisolated enum VerificationStatus: Decodable, Sendable, Equatable {
        case processing
        case approved
        case rejected
        case manualReview
        case unknown

        init(from decoder: Decoder) throws {
            switch try decoder.singleValueContainer().decode(String.self) {
            case "PROCESSING": self = .processing
            case "APPROVED": self = .approved
            case "REJECTED": self = .rejected
            case "MANUAL_REVIEW": self = .manualReview
            default: self = .unknown
            }
        }
    }

    /// `GET /verifications/me`의 한 건. 최신순. 제출 시각은 없고 날짜만 있다.
    nonisolated struct Verification: Decodable, Sendable {
        let verificationId: Int64
        /// `2026-09-29`
        let date: String
        let areaName: String
        let reviewStatus: VerificationStatus
        /// 반려일 때만 있다.
        let failReasons: [String]?
    }

    nonisolated enum ApplicationStatus: Decodable, Sendable, Equatable {
        case pending
        case approved
        case rejected
        case unknown

        init(from decoder: Decoder) throws {
            switch try decoder.singleValueContainer().decode(String.self) {
            case "PENDING": self = .pending
            case "APPROVED": self = .approved
            case "REJECTED": self = .rejected
            default: self = .unknown
            }
        }
    }

    /// `GET /applications/me`. 신청한 적이 없으면 404 `NO_APPLICATION`.
    nonisolated struct Application: Decodable, Sendable {
        let status: ApplicationStatus
        let order: Int64
        /// 승인됐지만 아직 구역을 배정받지 않았다.
        let waitingForAssignment: Bool
    }

    nonisolated enum PeriodStatus: Decodable, Sendable, Equatable {
        case upcoming
        case open
        case closed
        case unknown

        init(from decoder: Decoder) throws {
            switch try decoder.singleValueContainer().decode(String.self) {
            case "UPCOMING": self = .upcoming
            case "OPEN": self = .open
            case "CLOSED": self = .closed
            default: self = .unknown
            }
        }
    }

    /// `GET /recruitments/current`. 내 학반의 모집이 없으면 404 `NO_ACTIVE_RECRUITMENT`.
    nonisolated struct CurrentRecruitment: Decodable, Sendable {
        let recruitmentId: Int64
        /// `2026-2`
        let semester: String
        let grade: Int
        let classNo: Int
        let periodStatus: PeriodStatus
        let maxCount: Int
        let currentApplicants: Int
        let isFull: Bool
        let alreadyApplied: Bool
    }

    /// `GET /notices`의 한 건. 최신순.
    nonisolated struct NoticeListItem: Decodable, Sendable {
        let noticeId: Int64
        let title: String
        /// 본문 앞부분(공백 정리 후 최대 100자).
        let preview: String
        /// 상세를 열어 본 공지인지.
        let isRead: Bool
        /// `2026-09-01T09:00:00`
        let createdAt: String
    }
}
