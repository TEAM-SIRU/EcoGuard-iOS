/// `GET /assignments/me`.
nonisolated struct MyAssignmentResponseDTO: Decodable, Sendable {
    struct Coordinates: Decodable, Sendable {
        let x: Double
        let y: Double
    }

    struct Member: Decodable, Sendable {
        let studentId: Int64
        let studentNumber: String?
        let name: String
    }

    let areaId: Int64
    let areaName: String
    let description: String?
    /// "07:20~08:10". 서버는 비어 있을 수 있게 둔다.
    let cleanTime: String?
    /// 도면 좌표. 아직 서버 값이 모두 0이고 층 정보가 없어 쓰지 않는다.
    let mapCoordinates: Coordinates
    /// 같은 구역에 배정된 학생(나 포함), 배정 순.
    let members: [Member]
}
