#if DEBUG
import Foundation

/// UI 테스트용(DEBUG). Mock 공고의 신청 기간을 실행 시각 기준(어제 ~ 내일)으로 옮긴다.
/// Mock 고정 기간이 지나도 `신청하기`가 켜지는 공고를 띄울 수 있다. 환경 변수 `ECO_MOCK_RECRUITMENT_PERIOD=current`로 켠다.
final class CurrentPeriodRecruitmentRepository: RecruitmentRepository {
    static let environmentKey = "ECO_MOCK_RECRUITMENT_PERIOD"

    private let base: RecruitmentRepository
    private let now: () -> Date

    init(base: RecruitmentRepository, now: @escaping () -> Date = Date.init) {
        self.base = base
        self.now = now
    }

    /// 환경 변수가 켜져 있으면 감싸고, 아니면 그대로 돌려준다.
    static func wrappingIfRequested(_ base: RecruitmentRepository) -> RecruitmentRepository {
        ProcessInfo.processInfo.environment[environmentKey] == "current" ? CurrentPeriodRecruitmentRepository(base: base) : base
    }

    func fetchRecruitment() async throws -> RecruitmentDetail? {
        guard let detail = try await base.fetchRecruitment() else { return nil }
        let day: TimeInterval = 24 * 60 * 60
        return RecruitmentDetail(
            recruitment: detail.recruitment,
            startDate: now().addingTimeInterval(-day),
            endDate: now().addingTimeInterval(day),
            activityWindow: detail.activityWindow,
            phase: detail.phase,
            myApplication: detail.myApplication
        )
    }

    func fetchApplicant() async throws -> Applicant {
        try await base.fetchApplicant()
    }

    func apply(motivation: String) async throws -> RecruitmentApplication {
        try await base.apply(motivation: motivation)
    }

    func fetchMyApplication() async throws -> RecruitmentApplication? {
        try await base.fetchMyApplication()
    }
}
#endif
