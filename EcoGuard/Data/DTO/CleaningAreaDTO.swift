/// `GET /assignments/me`.
nonisolated struct MyAssignmentResponseDTO: Decodable, Sendable {
    struct Member: Decodable, Sendable {
        let studentId: Int64
        let studentNumber: String?
        let name: String
    }

    let areaId: Int64
    /// 앱 도면에서 내 구역 칸을 찾는 코드(`main_stair_a` 등). 도면 표시에만 쓰여 없어도 구역은 보여 준다.
    let zoneCode: String?
    let areaName: String
    let description: String?
    /// "07:20~08:10". 서버는 비어 있을 수 있게 둔다.
    let cleanTime: String?
    /// 같은 구역에 배정된 학생(나 포함), 배정 순.
    let members: [Member]
}
