import Foundation

/// 학교 도면. 서버에 도면이 없어 앱이 가진다.
///
/// 학교가 준 1층 평면도(본관·실습동 1F, 금봉관 1F)를 휴대폰 폭에 맞게 줄로 단순화했다. 층마다 구조가 같다고 해서 같은 배치를 1~4층에 쓴다.
/// 본관·실습동은 서쪽(계단 A)에서 동쪽(계단 D) 순서로 줄을 놓고, 그 아래 연결통로와 금봉관을 둔다.
/// - 본관 1~4층. 현관 A~D·체력단련실은 1층에만 있고, 2층부터 그 자리는 교실로 둔다.
/// - 실습동 계단 D는 1~3층만 청소 구역이다. 4층 칸은 청소하지 않는 칸으로 둔다.
/// - 금봉관 1~3층. 4층에는 금봉관 칸 없이 계단 E(4층 철문 앞)만 둔다.
/// - 본관-금봉관 연결통로는 평면도에 없다. 구역 설명("계단 A쪽 현관, 금봉관 연결통로 방향")으로 본관 서쪽 끝에서 금봉관으로 이어진다고 추정했다.
/// - 위쪽 출입문(행정실과 방송실 사이)은 현관 C, 계단 B 옆 아래쪽 출입문은 현관 B로 추정했다.
/// - 금봉관 2·3층 시청각실 자리는 구역 설명의 복도 시작점(위클래스·도서관)으로 두었다.
enum SchoolFloorPlan {
    static let floorNumbers = 1...4

    static let floors: [FloorPlan] = floorNumbers.map { floor in
        FloorPlan(id: "\(floor)F", name: "\(floor)층", rows: rows(floor: floor))
    }

    /// `zoneCode` 칸을 모든 층에서 내 구역으로 바꾸고, 내 구역이 있는 가장 낮은 층을 고른다.
    /// 도면에 없는(모르는) 코드거나 nil이면 하이라이트 없이 첫 층을 고른다.
    static func highlighting(_ zoneCode: CleaningZoneCode?, in floors: [FloorPlan] = floors) -> (floors: [FloorPlan], myFloorID: String) {
        let highlighted = floors.map { floor in
            FloorPlan(id: floor.id, name: floor.name, rows: floor.rows.map { row in
                row.map { cell in
                    guard let zoneCode, cell.zoneCode == zoneCode else { return cell }
                    return FloorPlanCell(id: cell.id, name: cell.name, kind: .mine, zoneCode: cell.zoneCode, span: cell.span)
                }
            })
        }
        let myFloor = highlighted.first { $0.rows.joined().contains { $0.kind == .mine } } ?? highlighted.first
        return (highlighted, myFloor?.id ?? "")
    }

    private static func rows(floor: Int) -> [[FloorPlanCell]] {
        let isFirst = floor == 1
        func zone(_ id: String, _ name: String, _ code: CleaningZoneCode) -> FloorPlanCell {
            FloorPlanCell(id: "\(floor)F-\(id)", name: name, kind: .cleaning, zoneCode: code, span: 1)
        }
        func room(_ id: String, _ name: String) -> FloorPlanCell {
            FloorPlanCell(id: "\(floor)F-\(id)", name: name, kind: .notCleaning, zoneCode: nil, span: 1)
        }
        /// 1층에만 있는 구역. 다른 층은 같은 자리를 교실로 둔다.
        func firstFloorZone(_ id: String, _ name: String, _ code: CleaningZoneCode) -> FloorPlanCell {
            isFirst ? zone(id, name, code) : room(id, "교실")
        }

        var rows: [[FloorPlanCell]] = [
            // 본관 서쪽: 여화장실, 계단 A, 계단 A쪽 현관
            [room("restroom-west", "화장실"), zone("stair-a", "계단 A", .mainStairA), firstFloorZone("entrance-a", "현관 A", .mainEntranceA)],
            // 행정실, 계단 B, 계단 B쪽 현관
            [room("office", isFirst ? "행정실" : "교실"), zone("stair-b", "계단 B", .mainStairB), firstFloorZone("entrance-b", "현관 B", .mainEntranceB)],
            [mainCorridor(floor: floor)],
            // 위쪽 출입문, 계단 C, 남화장실
            [firstFloorZone("entrance-c", "현관 C", .mainEntranceC), zone("stair-c", "계단 C", .mainStairC), room("restroom-east", "화장실")],
            // 실습동
            [room("lab", "실습실"), firstFloorZone("fitness-room", "체력단련실", .mainFitnessRoomF1), room("prep-room", isFirst ? "준비실" : "교실")],
            [
                room("server-room", isFirst ? "서버실" : "교실"),
                firstFloorZone("entrance-d", "현관 D", .mainEntranceD),
                floor <= 3 ? zone("stair-d", "계단 D", .practiceStairD) : room("stair-d", "계단 D"),
            ],
        ]
        if let connector = connectorCode(floor: floor), let corridor = geumbongCorridorCode(floor: floor) {
            rows.append([zone("connector", "본관-금봉관 연결통로", connector)])
            rows.append([zone("geumbong-corridor", "금봉관 복도", corridor)])
            rows.append([
                room("geumbong-hall", geumbongHallName(floor: floor)),
                room("geumbong-room", isFirst ? "식생활관" : "교실"),
                zone("stair-e", "계단 E", .geumbongStairE),
            ])
        } else {
            // 금봉관은 3층까지다. 4층에는 계단 E 철문 앞만 있다.
            rows.append([zone("stair-e", "계단 E 철문 앞", .geumbongStairE)])
        }
        return rows
    }

    private static func mainCorridor(floor: Int) -> FloorPlanCell {
        let code: CleaningZoneCode? = switch floor {
        case 3: .mainCorridorF3
        case 4: .mainCorridorF4
        default: nil
        }
        return FloorPlanCell(id: "\(floor)F-main-corridor", name: "본관 복도", kind: code == nil ? .notCleaning : .cleaning, zoneCode: code, span: 1)
    }

    private static func connectorCode(floor: Int) -> CleaningZoneCode? {
        switch floor {
        case 1: .connectorF1
        case 2: .connectorF2
        case 3: .connectorF3
        default: nil
        }
    }

    private static func geumbongCorridorCode(floor: Int) -> CleaningZoneCode? {
        switch floor {
        case 1: .geumbongCorridorF1
        case 2: .geumbongCorridorF2
        case 3: .geumbongCorridorF3
        default: nil
        }
    }

    /// 금봉관 복도가 시작하는 방. 구역 설명의 시작점(1층 시청각실, 2층 위클래스, 3층 도서관)이다.
    private static func geumbongHallName(floor: Int) -> String {
        switch floor {
        case 1: "시청각실"
        case 2: "위클래스"
        default: "도서관"
        }
    }
}
