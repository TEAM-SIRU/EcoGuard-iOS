import Foundation

extension DIContainer {
    /// 활동 기록을 볼 수 있는 가장 이른 달. 서비스 시작 시점이 정해지기 전까지 2026학년도 1학기 시작(3월)으로 둔다.
    static let activityRecordsEarliestMonth = YearMonth(year: 2026, month: 3)

    /// 활동 기록 화면.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다.
    func makeActivityRecordsViewModel(
        repository: ActivityRepository = MockActivityRepository(),
        now: @escaping () -> Date = Date.init
    ) -> ActivityRecordsViewModel {
        ActivityRecordsViewModel(
            fetchActivityMonthUseCase: FetchActivityMonthUseCase(activityRepository: repository),
            earliestMonth: Self.activityRecordsEarliestMonth,
            now: now
        )
    }
}
