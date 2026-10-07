extension CleaningWindow {
    /// 서버에 시간이 없거나 읽을 수 없을 때 쓰는 청소 시간. 서버 청소 구역 시드의 `clean-time: "07:20~08:10"`.
    static let serverDefault = CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10)
}

extension MyAssignmentResponseDTO {
    /// 도면(층·칸)은 서버에 없어 `floors`(앱이 가진 도면)를 받고, `zoneCode` 칸을 모든 층에서 내 구역으로 표시한다.
    /// 구성원 중 `myUserID`(내 정보의 사용자 ID)인 학생을 나로 표시한다. 청소 시간이 없거나 읽을 수 없으면 기본값을 쓴다.
    func toDomain(floors: [FloorPlan], myUserID: String?) -> CleaningAreaSummary {
        let window = cleanTime.flatMap { ServerDate.minuteRange($0) }
            .map { CleaningWindow(startMinute: $0.start, endMinute: $0.end) } ?? .serverDefault
        let area = MyCleaningArea(
            zoneCode: zoneCode.map(CleaningZoneCode.init(rawValue:)),
            range: areaName,
            description: description ?? "",
            startMinute: window.startMinute,
            endMinute: window.endMinute,
            memberNames: members.map(\.name),
            myName: members.first { String($0.studentId) == myUserID }?.name
        )
        let plan = SchoolFloorPlan.highlighting(area.zoneCode, in: floors)
        return .assigned(floors: plan.floors, myFloorID: plan.myFloorID, area: area)
    }
}
