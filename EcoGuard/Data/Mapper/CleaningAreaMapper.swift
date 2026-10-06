extension CleaningWindow {
    /// 서버에 시간이 없거나 읽을 수 없을 때 쓰는 청소 시간. 서버 청소 구역 시드의 `clean-time: "07:20~08:10"`.
    static let serverDefault = CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10)
}

extension MyAssignmentResponseDTO {
    /// 도면(층·칸)은 서버에 없어 `floors`(앱이 가진 도면)를 받는다. 내 구역이 어느 칸인지도 알 수 없어 `.mine` 칸은 두지 않는다.
    /// 응답에 누가 나인지 없어 `myName`은 밖에서 받는다(서버 요청 목록). 청소 시간이 없거나 읽을 수 없으면 기본값을 쓴다.
    func toDomain(floors: [FloorPlan], myName: String?) -> CleaningAreaSummary {
        let window = cleanTime.flatMap { ServerDate.minuteRange($0) }
            .map { CleaningWindow(startMinute: $0.start, endMinute: $0.end) } ?? .serverDefault
        let area = MyCleaningArea(
            range: areaName,
            description: description ?? "",
            startMinute: window.startMinute,
            endMinute: window.endMinute,
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
