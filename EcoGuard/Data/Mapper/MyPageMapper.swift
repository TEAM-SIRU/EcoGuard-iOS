enum MyPageMapper {
    /// 환경지킴이 = 구역을 배정받았거나 신청이 받아들여짐(배정 대기).
    /// 신청은 바로 승인되므로 예전 신청에 남은 `PENDING`도 승인으로 본다. 미선발(`REJECTED`)만 뺀다.
    static func summary(
        user: CurrentUser,
        activity: MyActivityResponseDTO,
        assignment: HomeDTO.Assignment?,
        application: HomeDTO.Application?
    ) -> MyPageSummary {
        MyPageSummary(
            profile: UserProfile(
                name: user.name,
                grade: user.grade,
                classNumber: user.classNumber,
                isGuardian: assignment != nil || application.map { $0.status != .rejected } == true
            ),
            monthlyApprovedCount: activity.summary.approvedCount,
            monthlyActivityMinutes: activity.monthlyMinutes,
            cleaningAreaName: assignment?.areaName,
            hasApplied: application != nil
        )
    }
}
