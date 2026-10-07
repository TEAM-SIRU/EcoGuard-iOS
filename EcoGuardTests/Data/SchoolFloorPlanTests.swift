import Testing
@testable import EcoGuard

@MainActor
struct SchoolFloorPlanTests {
    private static func cells(_ floor: FloorPlan) -> [FloorPlanCell] {
        Array(floor.rows.joined())
    }

    /// 층 이름(1~4) 순서로 `zoneCode` 칸이 있는 층.
    private static func floorNumbers(of zoneCode: CleaningZoneCode) -> [Int] {
        SchoolFloorPlan.floors.enumerated()
            .filter { cells($0.element).contains { $0.zoneCode == zoneCode } }
            .map { $0.offset + 1 }
    }

    @Test func floorsAreOneToFour() {
        #expect(SchoolFloorPlan.floors.map(\.id) == ["1F", "2F", "3F", "4F"])
        #expect(SchoolFloorPlan.floors.map(\.name) == ["1층", "2층", "3층", "4층"])
    }

    /// 서버 18개 구역이 모두 도면 칸에 있고, 도면에는 서버에 없는 구역 코드가 없다.
    @Test func everyServerZoneHasCell() {
        let mapped = Set(SchoolFloorPlan.floors.flatMap { Self.cells($0).compactMap(\.zoneCode) })
        #expect(mapped == Set(CleaningZoneCode.all))
    }

    /// 칸 ID는 도면 전체에서 겹치지 않는다(층 탭·하이라이트가 칸을 구분한다).
    @Test func cellIDsAreUnique() {
        let ids = SchoolFloorPlan.floors.flatMap { Self.cells($0).map(\.id) }
        #expect(Set(ids).count == ids.count)
    }

    /// 청소 구역 칸만 `zoneCode`가 있고, 처음엔 내 구역 칸이 없다.
    @Test func kindFollowsZoneCode() {
        for cell in SchoolFloorPlan.floors.flatMap(Self.cells) {
            #expect(cell.kind == (cell.zoneCode == nil ? .notCleaning : .cleaning), "\(cell.id)")
        }
    }

    @Test(arguments: [
        (CleaningZoneCode.mainStairA, [1, 2, 3, 4]),
        (.mainStairB, [1, 2, 3, 4]),
        (.mainStairC, [1, 2, 3, 4]),
        (.practiceStairD, [1, 2, 3]),
        (.geumbongStairE, [1, 2, 3, 4]),
        (.mainEntranceA, [1]),
        (.mainEntranceB, [1]),
        (.mainEntranceC, [1]),
        (.mainEntranceD, [1]),
        (.mainFitnessRoomF1, [1]),
        (.geumbongCorridorF1, [1]),
        (.connectorF1, [1]),
        (.geumbongCorridorF2, [2]),
        (.connectorF2, [2]),
        (.geumbongCorridorF3, [3]),
        (.connectorF3, [3]),
        (.mainCorridorF3, [3]),
        (.mainCorridorF4, [4]),
    ] as [(CleaningZoneCode, [Int])])
    func zoneFloorRange(zoneCode: CleaningZoneCode, floors: [Int]) {
        #expect(Self.floorNumbers(of: zoneCode) == floors)
    }

    /// 여러 층에 걸친 구역은 해당 층마다 내 구역으로 표시하고, 가장 낮은 층을 먼저 연다.
    @Test(arguments: [
        (CleaningZoneCode.mainStairA, "1F"),
        (.geumbongCorridorF2, "2F"),
        (.mainCorridorF4, "4F"),
        (.practiceStairD, "1F"),
    ] as [(CleaningZoneCode, String)])
    func highlightingMarksEveryFloor(zoneCode: CleaningZoneCode, myFloorID: String) {
        let plan = SchoolFloorPlan.highlighting(zoneCode)

        #expect(plan.myFloorID == myFloorID)
        for (floor, original) in zip(plan.floors, SchoolFloorPlan.floors) {
            for (cell, originalCell) in zip(Self.cells(floor), Self.cells(original)) {
                let expected: FloorPlanCell.Kind = originalCell.zoneCode == zoneCode ? .mine : originalCell.kind
                #expect(cell.kind == expected, "\(cell.id)")
                #expect(cell.id == originalCell.id)
            }
        }
        let mineFloors = plan.floors.enumerated().filter { Self.cells($0.element).contains { $0.kind == .mine } }.map { $0.offset + 1 }
        #expect(mineFloors == Self.floorNumbers(of: zoneCode))
    }

    /// 모르는 구역 코드나 코드가 없으면 하이라이트 없이 도면 그대로 첫 층을 연다.
    @Test(arguments: [CleaningZoneCode(rawValue: "annex_corridor_f9"), nil] as [CleaningZoneCode?])
    func unknownZoneHasNoHighlight(zoneCode: CleaningZoneCode?) {
        let plan = SchoolFloorPlan.highlighting(zoneCode)

        #expect(plan.floors == SchoolFloorPlan.floors)
        #expect(plan.myFloorID == "1F")
    }

    /// 휴대폰 폭에서 칸 이름이 줄바꿈되지 않도록 한 줄에 칸을 3개까지 둔다.
    @Test func rowsHaveAtMostThreeCells() {
        for floor in SchoolFloorPlan.floors {
            #expect(floor.rows.allSatisfy { (1...3).contains($0.count) }, "\(floor.name)")
        }
    }
}
