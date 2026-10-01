import Foundation

/// 내 환경지킴이 신청.
struct RecruitmentApplication: Hashable {
    enum Status: Hashable {
        case pending
        case approved
        case rejected
    }

    /// 반에서 몇 번째로 신청했는지.
    let order: Int
    let appliedAt: Date
    let status: Status
    /// 승인 후 선생님이 청소 구역을 배정했는지.
    let isAreaAssigned: Bool
}
