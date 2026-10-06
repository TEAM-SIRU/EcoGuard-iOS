import Foundation

extension CurrentRecruitmentResponseDTO {
    /// `myApplication`은 `alreadyApplied`일 때 `GET /applications/me`로 따로 받아 넣는다.
    /// 학기·활동 시간은 보여 주기만 하는 값이라 읽을 수 없으면 실패로 두지 않고 기본값을 쓴다.
    func toDomain(myApplication: RecruitmentApplication?) throws -> RecruitmentDetail {
        let startDate = try ServerDate.requiredDateTime(period.start)
        // 신청했는데 보여 줄 신청이 없으면(반려 등) 다시 신청할 수 없으므로 마감으로 보여 준다.
        let phase = alreadyApplied && myApplication == nil ? .ended : periodStatus.phase
        return RecruitmentDetail(
            recruitment: Recruitment(
                semester: ServerSemester.number(semester),
                capacityPerClass: maxCount,
                className: "\(grade)학년 \(classNo)반",
                appliedCount: currentApplicants
            ),
            startDate: startDate,
            endDate: try ServerDate.requiredDateTime(period.end),
            activityWindow: activityTime.window,
            phase: phase,
            myApplication: myApplication
        )
    }
}

extension CurrentRecruitmentResponseDTO.PeriodStatus {
    var phase: RecruitmentDetail.Phase {
        switch self {
        case .upcoming: .upcoming
        case .open: .open
        case .closed: .ended
        }
    }
}

extension CurrentRecruitmentResponseDTO.ActivityTime {
    /// `"07:20:00"`~`"08:10:00"` → 분. 읽을 수 없으면 서버 기본값(07:20~08:10).
    var window: CleaningWindow {
        guard let start = Self.minuteOfDay(start), let end = Self.minuteOfDay(end), start < end else { return .serverDefault }
        return CleaningWindow(startMinute: start, endMinute: end)
    }

    /// `HH:mm` 또는 `HH:mm:ss`(초는 버린다).
    private static func minuteOfDay(_ string: String) -> Int? {
        guard let match = string.wholeMatch(of: /(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?/),
              let hour = Int(match.1), let minute = Int(match.2), (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }
}

extension ApplyResponseDTO {
    /// 막 신청했으므로 구역은 아직 배정 전이다.
    func toDomain() throws -> RecruitmentApplication {
        RecruitmentApplication(order: order, appliedAt: try ServerDate.requiredDateTime(appliedAt), isAreaAssigned: false)
    }
}

extension ApplicationStatusResponseDTO {
    /// 미선발(`REJECTED`)이면 nil. 서버 #16부터 신청은 바로 승인되고 반려를 만드는 코드가 없지만, 열거형과 이전 데이터에 남아 있어 막아 둔다.
    func toDomain() throws -> RecruitmentApplication? {
        guard status != .rejected else { return nil }
        return RecruitmentApplication(
            order: order,
            appliedAt: try ServerDate.requiredDateTime(appliedAt),
            // 승인이 아니면(이전 데이터의 PENDING) 서버가 waitingForAssignment를 false로 주므로 승인됐을 때만 배정 여부로 본다.
            isAreaAssigned: status == .approved && !waitingForAssignment
        )
    }
}
