import Foundation

/// 서버 연동 전까지 쓰는 Mock. Figma `05 청소구역` 프레임의 데이터를 지연 후 돌려준다.
final class MockCleaningAreaRepository: CleaningAreaRepository {
    enum Scenario: CaseIterable {
        case assigned
        case unassigned
        case failure
    }

    struct FetchFailedError: Error {}

    private var scenarios: [Scenario]
    private let delay: Duration
    private let zoneCode: CleaningZoneCode
    private(set) var fetchCallCount = 0

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    /// 배정 상태면 `zoneCode` 칸을 내 구역으로 표시한다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1), zoneCode: CleaningZoneCode = Fixture.zoneCode) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
        self.zoneCode = zoneCode
    }

    convenience init(scenario: Scenario = .assigned, delay: Duration = .seconds(1)) {
        self.init(scenarios: [scenario], delay: delay)
    }

    /// 다른 Mock과 상태를 같이 쓴다. 홈이 활동 중일 때만 구역이 배정돼 있다.
    convenience init(store: MockStore, delay: Duration = .seconds(1)) {
        self.init(scenarios: [store.homeScenario.isActive ? .assigned : .unassigned], delay: delay, zoneCode: store.zoneCode)
    }

    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        fetchCallCount += 1
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        switch scenario {
        case .assigned: return Fixture.assigned(zoneCode: zoneCode)
        case .unassigned: return .unassigned
        case .failure: throw FetchFailedError()
        }
    }
}

extension MockCleaningAreaRepository {
    /// Figma `05 청소구역` (239:3) 문구 그대로. 도면은 실제 학교 도면이다.
    enum Fixture {
        /// 기본 배정 구역. Figma 문구가 2층 구역이라 2층에만 있는 구역을 둔다.
        static let zoneCode = CleaningZoneCode.geumbongCorridorF2

        static let assigned = assigned(zoneCode: zoneCode)

        static func assigned(zoneCode: CleaningZoneCode) -> CleaningAreaSummary {
            let plan = SchoolFloorPlan.highlighting(zoneCode)
            return .assigned(floors: plan.floors, myFloorID: plan.myFloorID, area: area(zoneCode: zoneCode))
        }

        static let area = area(zoneCode: zoneCode)

        static func area(zoneCode: CleaningZoneCode) -> MyCleaningArea {
            MyCleaningArea(
                zoneCode: zoneCode,
                range: "2-1반 앞부터 중앙 계단 앞까지",
                description: "바닥을 쓸고 창틀 먼지를 닦아요",
                startMinute: 8 * 60,
                endMinute: 8 * 60 + 10,
                memberNames: ["김서연", "이도윤", "최민준"],
                myName: "최민준"
            )
        }
    }
}
