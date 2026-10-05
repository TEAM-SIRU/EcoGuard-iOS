extension MyAssignmentResponseDTO {
    /// 도면(층·칸)은 서버에 없어 `floors`(앱이 가진 도면)를 받는다. 내 구역이 어느 칸인지도 알 수 없어 `.mine` 칸은 두지 않는다.
    /// 응답에 누가 나인지 없어 `myName`은 밖에서 받는다(서버 요청 목록).
    func toDomain(floors: [FloorPlan], myName: String) throws -> CleaningAreaSummary {
        guard let cleanTime, let window = ServerDate.minuteRange(cleanTime) else { throw APIError.decoding }
        let area = MyCleaningArea(
            range: areaName,
            description: description ?? "",
            startMinute: window.start,
            endMinute: window.end,
            memberNames: members.map(\.name),
            myName: myName
        )
        let floors = floors.map { floor in
            FloorPlan(id: floor.id, name: floor.name, rows: floor.rows.map { row in
                row.map { cell in
                    cell.kind == .mine ? FloorPlanCell(id: cell.id, name: cell.name, kind: .cleaning, span: cell.span) : cell
                }
            })
        }
        return .assigned(floors: floors, myFloorID: floors.first?.id ?? "", area: area)
    }
}
