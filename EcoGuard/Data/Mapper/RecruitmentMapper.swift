import Foundation

extension CurrentRecruitmentResponseDTO {
    /// 학기는 문자열 끝 숫자("2", "2026-2", "2학기")로 읽고 1·2학기만 받는다. 형식은 서버와 정해야 한다(서버 요청 목록).
    var semesterNumber: Int? {
        semester.firstMatch(of: /(\d+)\D*$/).flatMap { Int($0.1) }.flatMap { (1...2).contains($0) ? $0 : nil }
    }

    /// `myApplication`은 `alreadyApplied`일 때 `GET /applications/me`로 따로 받아 넣는다.
    /// 활동 시간은 공고에 없어 `activityWindow`(앱 기본값)를 쓴다.
    func toDomain(activityWindow: CleaningWindow, myApplication: RecruitmentApplication?) throws -> RecruitmentDetail {
        guard let semesterNumber else { throw APIError.decoding }
        // 신청했는데 보여 줄 신청이 없으면(반려 등) 다시 신청할 수 없으므로 마감으로 보여 준다.
        let phase = alreadyApplied && myApplication == nil ? .ended : periodStatus.phase
        return RecruitmentDetail(
            recruitment: Recruitment(
                semester: semesterNumber,
                capacityPerClass: maxCount,
                className: "\(grade)학년 \(classNo)반",
                appliedCount: currentApplicants
            ),
            startDate: try ServerDate.requiredDateTime(period.start),
            endDate: try ServerDate.requiredDateTime(period.end),
            activityWindow: activityWindow,
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

extension ApplyResponseDTO {
    /// 신청 응답에는 신청 시각이 없어 응답을 받은 시각(`receivedAt`)을 쓴다. 막 신청했으므로 초 단위까지 맞다.
    func toDomain(receivedAt: Date) -> RecruitmentApplication {
        RecruitmentApplication(order: order, appliedAt: receivedAt, isAreaAssigned: false)
    }
}

extension ApplicationStatusResponseDTO {
    /// 반려(`REJECTED`)면 nil. 앱은 선착순 즉시 확정이라 반려 상태가 없다(서버는 정원 안에서만 신청을 받아 확정 때 모두 승인한다).
    /// `appliedAt`이 아직 서버에 없어 없으면 `fallbackAppliedAt`을 쓴다.
    func toDomain(fallbackAppliedAt: Date) throws -> RecruitmentApplication? {
        guard status != .rejected else { return nil }
        return RecruitmentApplication(
            order: order,
            appliedAt: try appliedAt.map { try ServerDate.requiredDateTime($0) } ?? fallbackAppliedAt,
            // 승인 전(PENDING)에는 서버가 waitingForAssignment를 false로 주므로 승인됐을 때만 배정 여부로 본다.
            isAreaAssigned: status == .approved && !waitingForAssignment
        )
    }
}
