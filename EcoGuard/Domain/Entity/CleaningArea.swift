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

/// 내 청소 구역 상세.
struct MyCleaningArea: Hashable {
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
