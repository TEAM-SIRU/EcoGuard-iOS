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
    /// 도면은 실제 학교 도면, 구역은 서버 구역 목록이다.
    enum Fixture {
        /// 기본 배정 구역. Figma `05 청소구역` (239:3)이 2층을 열어 두어 2층에만 있는 구역을 둔다.
        static let zoneCode = CleaningZoneCode.geumbongCorridorF2

        static let assigned = assigned(zoneCode: zoneCode)

        static func assigned(zoneCode: CleaningZoneCode) -> CleaningAreaSummary {
            let plan = SchoolFloorPlan.highlighting(zoneCode)
            return .assigned(floors: plan.floors, myFloorID: plan.myFloorID, area: area(zoneCode: zoneCode))
        }

        static let area = area(zoneCode: zoneCode)

        /// 구역 이름·설명은 서버 구역 목록, 시간은 서버 기본값(07:20~08:10). 구성원은 Figma 문구 그대로.
        static func area(zoneCode: CleaningZoneCode) -> MyCleaningArea {
            let zone = zones[zoneCode] ?? (name: "청소 구역", description: "")
            return MyCleaningArea(
                zoneCode: zoneCode,
                range: zone.name,
                description: zone.description,
                startMinute: CleaningWindow.serverDefault.startMinute,
                endMinute: CleaningWindow.serverDefault.endMinute,
                memberNames: ["김서연", "이도윤", "최민준"],
                myName: "최민준"
            )
        }

        /// 서버 청소 구역 목록의 이름·설명.
        static let zones: [CleaningZoneCode: (name: String, description: String)] = [
            .mainStairA: ("본관 계단 A", "1층→4층, 1층 현관 제외"),
            .mainEntranceA: ("본관 1층 현관 A", "계단 A쪽 현관·신발장, 금봉관 연결통로 방향"),
            .mainStairB: ("본관 계단 B", "1층→4층"),
            .mainStairC: ("본관 계단 C", "1층→4층"),
            .practiceStairD: ("실습동 계단 D", "1층→3층, 1층 현관 포함"),
            .geumbongStairE: ("금봉관 계단 E", "1층→4층, 4층 철문 앞까지"),
            .geumbongCorridorF1: ("금봉관 1층 복도", "시청각실 앞부터 급식실 방향 현관까지"),
            .connectorF1: ("본관-금봉관 연결통로 1층", "본관과 금봉관을 잇는 1층 통로"),
            .connectorF2: ("본관-금봉관 연결통로 2층", "본관과 금봉관을 잇는 2층 통로"),
            .connectorF3: ("본관-금봉관 연결통로 3층", "본관과 금봉관을 잇는 3층 통로"),
            .geumbongCorridorF2: ("금봉관 2층 복도", "ㄱ자 복도, 위클래스 앞부터"),
            .geumbongCorridorF3: ("금봉관 3층 복도", "ㄱ자 복도, 도서관 앞부터"),
            .mainFitnessRoomF1: ("본관 1층 체력단련실", "체력단련실"),
            .mainEntranceB: ("본관 1층 현관 B", "계단 B쪽 현관·외부 현관"),
            .mainEntranceC: ("본관 1층 현관 C", "계단 C쪽 현관·외부 현관"),
            .mainEntranceD: ("본관 1층 현관 D", "계단 D쪽 현관·신발장"),
            .mainCorridorF3: ("본관 3층 복도", "3층 복도 전체와 홈베이스"),
            .mainCorridorF4: ("본관 4층 복도", "4층 복도 전체와 홈베이스"),
        ]
    }
}
