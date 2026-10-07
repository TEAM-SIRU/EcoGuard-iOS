import Foundation

/// 학교 도면의 한 칸(교실·복도·계단·화장실 등).
struct FloorPlanCell: Hashable, Identifiable {
    enum Kind: Hashable {
        /// 내가 배정된 구역.
        case mine
        /// AI 인증을 지원해 청소하는 구역(1·2학기 기존 청소 구역).
        case cleaning
        /// 청소하지 않는 칸.
        case notCleaning
    }

    let id: String
    let name: String
    let kind: Kind
    /// 한 줄 안에서 차지하는 비율. Figma 복도는 2, 나머지는 1.
    let span: Int
}

/// 한 층의 도면. 줄마다 칸이 왼쪽부터 놓인다.
struct FloorPlan: Hashable, Identifiable {
    let id: String
    /// "2층"
    let name: String
    let rows: [[FloorPlanCell]]
}

/// 서버 청소 구역 코드(`zoneCode`). 앱 도면에서 내 구역 칸을 찾는 식별자다.
/// 서버가 구역을 늘려도 받은 값을 그대로 두어 모르는 코드로 실패하지 않는다.
struct CleaningZoneCode: RawRepresentable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    // 서버 청소 구역 시드의 18개 구역.
    static let mainStairA = Self(rawValue: "main_stair_a")
    static let mainStairB = Self(rawValue: "main_stair_b")
    static let mainStairC = Self(rawValue: "main_stair_c")
    static let mainEntranceA = Self(rawValue: "main_entrance_a")
    static let mainEntranceB = Self(rawValue: "main_entrance_b")
    static let mainEntranceC = Self(rawValue: "main_entrance_c")
    static let mainEntranceD = Self(rawValue: "main_entrance_d")
    static let mainFitnessRoomF1 = Self(rawValue: "main_fitness_room_f1")
    static let mainCorridorF3 = Self(rawValue: "main_corridor_f3")
    static let mainCorridorF4 = Self(rawValue: "main_corridor_f4")
    static let practiceStairD = Self(rawValue: "practice_stair_d")
    static let geumbongStairE = Self(rawValue: "geumbong_stair_e")
    static let geumbongCorridorF1 = Self(rawValue: "geumbong_corridor_f1")
    static let geumbongCorridorF2 = Self(rawValue: "geumbong_corridor_f2")
    static let geumbongCorridorF3 = Self(rawValue: "geumbong_corridor_f3")
    static let connectorF1 = Self(rawValue: "connector_f1")
    static let connectorF2 = Self(rawValue: "connector_f2")
    static let connectorF3 = Self(rawValue: "connector_f3")

    static let all: [Self] = [
        .mainStairA, .mainStairB, .mainStairC,
        .mainEntranceA, .mainEntranceB, .mainEntranceC, .mainEntranceD,
        .mainFitnessRoomF1, .mainCorridorF3, .mainCorridorF4,
        .practiceStairD, .geumbongStairE,
        .geumbongCorridorF1, .geumbongCorridorF2, .geumbongCorridorF3,
        .connectorF1, .connectorF2, .connectorF3,
    ]
}

/// 내 청소 구역 상세.
struct MyCleaningArea: Hashable {
    /// 도면에서 내 구역 칸을 찾는 코드. 서버가 주지 않으면 nil.
    let zoneCode: CleaningZoneCode?
    /// "2-1반 앞부터 중앙 계단 앞까지"
    let range: String
    /// "바닥을 쓸고 창틀 먼지를 닦아요"
    let description: String
    /// 청소 시간(하루 기준 분). 서버 값이다.
    let startMinute: Int
    let endMinute: Int
    /// 함께 배정된 학생 이름(나 포함).
    let memberNames: [String]
    /// 내 이름. 모르면 nil이고 멤버 목록에서 나를 따로 표시하지 않는다.
    let myName: String?
}

/// 청소 구역 화면 데이터.
enum CleaningAreaSummary: Hashable {
    /// 구역이 배정됐다. `myFloorID`는 내 구역이 있는 층이다.
    case assigned(floors: [FloorPlan], myFloorID: String, area: MyCleaningArea)
    /// 아직 배정된 구역이 없다.
    case unassigned
}
