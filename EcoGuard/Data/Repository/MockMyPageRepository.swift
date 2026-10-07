/// 서버 연동 전까지 쓰는 Mock. Figma `12 전체` (240:221)에 적힌 내 정보를 지연 후 돌려준다.
final class MockMyPageRepository: MyPageRepository {
    enum Scenario: CaseIterable {
        /// 환경지킴이로 활동 중(Figma 그대로).
        case guardian
        /// 아직 신청하지 않은 학생.
        case notApplied
        case failure
    }

    struct FetchFailedError: Error {}

    private var scenarios: [Scenario]
    private let delay: Duration
    /// 있으면 `.guardian`을 다른 Mock의 상태·기록으로 만든다(`MockStore`).
    private let store: MockStore?
    private(set) var fetchCallCount = 0

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1)) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
        self.store = nil
    }

    /// 다른 Mock과 상태를 같이 쓴다. `.guardian`이면 신청 여부·구역·이번 달 승인이 홈·활동 기록과 같다.
    init(store: MockStore, scenario: Scenario = .guardian, delay: Duration = .seconds(1)) {
        self.scenarios = [scenario]
        self.delay = delay
        self.store = store
    }

    convenience init(scenario: Scenario = .guardian, delay: Duration = .seconds(1)) {
        self.init(scenarios: [scenario], delay: delay)
    }

    func fetchMyPage() async throws -> MyPageSummary {
        fetchCallCount += 1
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        switch scenario {
        case .guardian: return store.map { Fixture.summary(store: $0) } ?? Fixture.guardian
        case .notApplied: return Fixture.notApplied
        case .failure: throw FetchFailedError()
        }
    }
}

extension MockMyPageRepository {
    enum Fixture {
        /// `store`의 신청·배정 상태와 이번 달 기록으로 만든 내 정보.
        static func summary(store: MockStore) -> MyPageSummary {
            let isGuardian = store.homeScenario.isActive || store.homeScenario == .awaitingAssignment
            return MyPageSummary(
                profile: UserProfile(name: guardian.profile.name, grade: guardian.profile.grade, classNumber: guardian.profile.classNumber, isGuardian: isGuardian),
                monthlyApprovedCount: store.monthlyApprovedCount,
                monthlyActivityMinutes: store.monthlyActivityMinutes,
                cleaningAreaName: store.homeScenario.isActive ? guardian.cleaningAreaName : nil,
                hasApplied: store.application != nil
            )
        }

        static let guardian = MyPageSummary(
            profile: UserProfile(name: "최민준", grade: 2, classNumber: 3, isGuardian: true),
            monthlyApprovedCount: 7,
            monthlyActivityMinutes: 70,
            cleaningAreaName: "본관 2층 복도 A",
            hasApplied: true
        )

        static let notApplied = MyPageSummary(
            profile: UserProfile(name: "최민준", grade: 2, classNumber: 3, isGuardian: false),
            monthlyApprovedCount: 0,
            monthlyActivityMinutes: 0,
            cleaningAreaName: nil,
            hasApplied: false
        )
    }
}
