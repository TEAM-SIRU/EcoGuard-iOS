import Foundation

/// 내 환경지킴이 신청. 신청하면 바로 확정된다(선착순).
struct RecruitmentApplication: Hashable {
    /// 반에서 몇 번째로 신청했는지.
    let order: Int
    let appliedAt: Date
    /// 승인 후 선생님이 청소 구역을 배정했는지.
    let isAreaAssigned: Bool
}
