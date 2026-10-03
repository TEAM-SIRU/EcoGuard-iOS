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
    private(set) var fetchCallCount = 0

    /// 호출마다 `scenarios`를 앞에서부터 하나씩 쓰고, 마지막 상태는 이후 호출에도 계속 쓴다.
    init(scenarios: [Scenario], delay: Duration = .seconds(1)) {
        precondition(!scenarios.isEmpty, "scenarios는 비어 있을 수 없다")
        self.scenarios = scenarios
        self.delay = delay
    }

    convenience init(scenario: Scenario = .assigned, delay: Duration = .seconds(1)) {
        self.init(scenarios: [scenario], delay: delay)
    }

    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        fetchCallCount += 1
        let scenario = scenarios.count > 1 ? scenarios.removeFirst() : scenarios[0]
        try await Task.sleep(for: delay)
        switch scenario {
        case .assigned: return Fixture.assigned
        case .unassigned: return .unassigned
        case .failure: throw FetchFailedError()
        }
    }
}

extension MockCleaningAreaRepository {
    /// Figma `05 청소구역` (239:3) 문구 그대로.
    enum Fixture {
        static let assigned = CleaningAreaSummary.assigned(floors: floors, myFloorID: "2F", area: area)

        static let area = MyCleaningArea(
            range: "2-1반 앞부터 중앙 계단 앞까지",
            description: "바닥을 쓸고 창틀 먼지를 닦아요",
            startMinute: 8 * 60,
            endMinute: 8 * 60 + 10,
            memberNames: ["김서연", "이도윤", "최민준"],
            myName: "최민준"
        )

        static let floors: [FloorPlan] = (1...4).map { floor in
            FloorPlan(id: "\(floor)F", name: "\(floor)층", rows: rows(floor: floor))
        }

        private static func rows(floor: Int) -> [[FloorPlanCell]] {
            func classroom(_ number: Int) -> FloorPlanCell {
                FloorPlanCell(id: "\(floor)F-\(number)", name: "교실 \(floor)-\(number)", kind: .notCleaning, span: 1)
            }
            let corridorA = FloorPlanCell(id: "\(floor)F-corridor-a", name: "복도 A", kind: floor == 2 ? .mine : .cleaning, span: 2)
            return [
                [classroom(1), classroom(2), classroom(3)],
                [corridorA, FloorPlanCell(id: "\(floor)F-stairs", name: "계단", kind: .notCleaning, span: 1)],
                [classroom(4), classroom(5), classroom(6)],
                [
                    FloorPlanCell(id: "\(floor)F-restroom", name: "화장실", kind: .cleaning, span: 1),
                    FloorPlanCell(id: "\(floor)F-corridor-b", name: "복도 B", kind: .cleaning, span: 2),
                ],
            ]
        }
    }
}
