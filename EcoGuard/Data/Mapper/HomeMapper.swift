import Foundation

/// 여러 응답을 홈 도메인으로 합친다. 날짜는 학교 시간대(KST) 기준이다.
nonisolated enum HomeMapper {
    /// 서버 `CleaningTimeWindow`의 기본 시간(07:20~08:10). 구역에 청소 시간이 없거나 형식이 틀리면 쓴다.
    static let defaultWindow = CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10)

    /// 학교 시간대(KST) 달력. 오늘·요일·주말 판단에 쓴다.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ServerDate.timeZone
        return calendar
    }()

    static func activeCleaning(
        assignment: HomeDTO.Assignment,
        weekly: WeeklyActivityResponseDTO,
        verifications: [HomeDTO.Verification],
        todayInfo: TodayVerificationResponseDTO?,
        now: Date
    ) throws -> ActiveCleaning {
        let today = calendar.startOfDay(for: now)
        let window = window(from: assignment.cleanTime)
        var todaySubmission: HomeDTO.Verification?
        var recent: [CleaningRecord] = []
        for verification in verifications {
            guard let day = ServerDate.date(verification.date) else { throw APIError.decoding }
            if day == today {
                todaySubmission = verification
            } else if day < today, recent.count < recentRecordLimit {
                recent.append(verification.toCleaningRecord(day: day))
            }
        }
        return ActiveCleaning(
            today: TodayCleaning(
                area: assignment.areaName,
                window: window,
                verification: todaySubmission.map(\.todayVerification)
                    ?? todayInfo.flatMap { verification(window: window, today: $0) }
                    ?? verification(window: window, now: now),
                // 서버가 제출 시각을 주지 않아 인증한 날 0시를 넣는다.
                submission: todaySubmission.map { TodaySubmission(id: String($0.verificationId), submittedAt: today) }
            ),
            week: try weekly.toDomain(now: now),
            recentRecords: recent
        )
    }

    /// 구역 배정 전. 모집 저장소와 같이 현재 공고에 한 신청(`recruitmentId`가 같음)만 내 신청으로 본다(지난 공고 신청으로 판단하지 않는다).
    /// - 공고 없음, 또는 신청하지 않았고 모집 기간이 아님 → 모집 없음
    /// - 신청하지 않았고 모집 중 → 모집
    /// - 신청함: 미선발 → 미선발, 그 밖 → 배정 대기. 서버 #16부터 신청하면 바로 승인되고 교사 확정이 없어
    ///   이전 데이터에 남은 `PENDING`이나 모르는 상태도 받아들여진 신청으로 본다.
    static func unassignedStatus(
        recruitment: HomeDTO.CurrentRecruitment?,
        application: HomeDTO.Application?,
        now: Date
    ) -> HomeStatus {
        guard let recruitment else { return .notRecruiting }
        guard recruitment.alreadyApplied else {
            return recruitment.periodStatus == .open ? .recruiting(recruitment.toDomain()) : .notRecruiting
        }
        let isRejected = application.map { $0.recruitmentId == recruitment.recruitmentId && $0.status == .rejected } == true
        return isRejected ? .notSelected : .awaitingAssignment
    }

    /// Figma `Recent section` 3건.
    static let recentRecordLimit = 3

    /// `07:20~08:10` → 분. 서버 `CleaningTimeWindow.parse`와 같이 형식이 틀리면 기본 시간.
    static func window(from cleanTime: String?) -> CleaningWindow {
        let parts = cleanTime?.split(separator: "~").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        guard parts.count == 2, let start = minuteOfDay(parts[0]), let end = minuteOfDay(parts[1]) else { return defaultWindow }
        return CleaningWindow(startMinute: start, endMinute: end)
    }

    /// 오늘 제출 전 상태를 오늘 인증 정보(`GET /verifications/today`)의 인증 가능 여부·사유·서버 시각으로 정한다.
    /// 방학은 서버만 알아 이 값으로만 알 수 있다. 서버 시각을 읽을 수 없으면 nil(기기 시각으로 정한다).
    static func verification(window: CleaningWindow, today info: TodayVerificationResponseDTO) -> TodayVerification? {
        guard let serverNow = ServerDate.dateTime(info.serverTime) else { return nil }
        if info.canSubmit {
            let deadline = calendar.startOfDay(for: serverNow).addingTimeInterval(TimeInterval(window.endMinute * 60))
            return .open(deadline: deadline)
        }
        if info.unavailableReason == "VACATION" { return .vacation }
        // 주말·시작 전·마감 뒤(그리고 모르는 사유)는 다음 인증 시작 시각을 기다린다. 서버가 안 된다고 했으니 열린 상태로 두지 않는다.
        let local = verification(window: window, now: serverNow)
        guard case .open = local else { return local }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: serverNow)) ?? serverNow
        return .notOpenYet(opensAt: opening(onOrAfter: tomorrow, window: window))
    }

    /// 오늘 제출 전 상태를 청소 시간과 기기 시각으로 정한다. 오늘 인증 정보를 받지 못했을 때 쓴다(방학은 알 수 없다).
    /// 시간이 지났거나 주말이면 다음 평일 시작 시각까지 `notOpenYet`으로 둔다(홈 도메인에 미제출 상태가 없다).
    static func verification(window: CleaningWindow, now: Date) -> TodayVerification {
        let today = calendar.startOfDay(for: now)
        let opensAt = today.addingTimeInterval(TimeInterval(window.startMinute * 60))
        // 서버는 종료 시각(`08:10:00`)이 지나면 받지 않는다(`!now.isAfter(end)`).
        let deadline = today.addingTimeInterval(TimeInterval(window.endMinute * 60))
        guard !calendar.isDateInWeekend(today) else { return .notOpenYet(opensAt: opening(onOrAfter: today, window: window)) }
        if now < opensAt { return .notOpenYet(opensAt: opensAt) }
        if now < deadline { return .open(deadline: deadline) }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return .notOpenYet(opensAt: opening(onOrAfter: tomorrow, window: window))
    }

    private static func opening(onOrAfter day: Date, window: CleaningWindow) -> Date {
        var day = day
        while calendar.isDateInWeekend(day), let next = calendar.date(byAdding: .day, value: 1, to: day) {
            day = next
        }
        return day.addingTimeInterval(TimeInterval(window.startMinute * 60))
    }

    private static func minuteOfDay(_ string: String) -> Int? {
        let parts = string.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return parts[0] * 60 + parts[1]
    }
}

nonisolated extension HomeDTO.Verification {
    var todayVerification: TodayVerification {
        switch reviewStatus {
        // 모르는 상태도 제출은 된 것이라 검수 중으로 둔다.
        case .processing, .unknown: .aiReviewing(submittedAt: nil)
        case .manualReview: .teacherReviewing(submittedAt: nil)
        case .approved: .approved(earnedMinutes: ActivityRecord.minutesPerApproval)
        case .rejected: .rejected(reason: (failReasons ?? []).joined(separator: "\n"))
        }
    }

    func toCleaningRecord(day: Date) -> CleaningRecord {
        let result: CleaningRecord.Result = switch reviewStatus {
        case .approved: .approved(earnedMinutes: ActivityRecord.minutesPerApproval)
        case .rejected: .rejected
        case .processing, .manualReview, .unknown: .processing
        }
        return CleaningRecord(id: String(verificationId), date: day, cleanedAt: nil, area: areaName, result: result)
    }
}

nonisolated extension WeeklyActivityResponseDTO {
    /// 월~금 다섯 칸. 서버는 배정 전 요일을 빼고 주므로 없는 요일은 미완료로 채운다.
    func toDomain(now: Date) throws -> WeeklyCleaning {
        let calendar = HomeMapper.calendar
        guard let monday = ServerDate.date(weekStart) else { throw APIError.decoding }
        var results: [Date: ActivityResultDTO] = [:]
        for day in days {
            guard let date = ServerDate.date(day.date) else { throw APIError.decoding }
            results[date] = day.result
        }
        let today = calendar.startOfDay(for: now)
        return WeeklyCleaning(days: (0..<5).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { return nil }
            return WeeklyCleaning.Day(
                weekday: calendar.component(.weekday, from: date),
                isToday: date == today,
                isCompleted: results[date] == .approved
            )
        })
    }
}

nonisolated extension HomeDTO.CurrentRecruitment {
    /// 학기를 읽을 수 없으면 홈을 실패로 두지 않고 학기 없이 보여 준다(`ServerSemester`).
    func toDomain() -> Recruitment {
        Recruitment(
            semester: ServerSemester.number(semester),
            capacityPerClass: maxCount,
            className: "\(grade)학년 \(classNo)반",
            appliedCount: currentApplicants
        )
    }
}

nonisolated extension HomeDTO.NoticeListItem {
    /// 홈 카드는 목록의 미리보기(일반 텍스트)를 보여 준다. 본문(마크다운)은 비워 둔다.
    /// 상세를 받으면 서버가 읽음으로 기록해 NEW가 사라지므로 홈에서는 상세를 받지 않는다.
    func toHomeNotice() throws -> Notice {
        guard let publishedAt = ServerDate.dateTime(createdAt) else { throw APIError.decoding }
        return Notice(id: String(noticeId), title: title, body: "", preview: preview, publishedAt: publishedAt, isRead: isRead)
    }
}
