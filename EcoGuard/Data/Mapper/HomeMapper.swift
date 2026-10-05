import Foundation

/// 여러 응답을 홈 도메인으로 합친다. 날짜는 학교 시간대(KST) 기준이다.
nonisolated enum HomeMapper {
    /// 서버 `CleaningTimeWindow`의 기본 시간(07:20~08:10). 구역에 청소 시간이 없거나 형식이 틀리면 쓴다.
    static let defaultWindow = CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10)

    private static var calendar: Calendar { ServerDate.calendar }

    static func activeCleaning(
        assignment: HomeDTO.Assignment,
        weekly: WeeklyActivityResponseDTO,
        verifications: [HomeDTO.Verification],
        now: Date
    ) throws -> ActiveCleaning {
        let today = calendar.startOfDay(for: now)
        let window = window(from: assignment.cleanTime)
        var todaySubmission: HomeDTO.Verification?
        var recent: [CleaningRecord] = []
        for verification in verifications {
            guard let day = ServerDate.day(verification.date) else { throw APIError.decoding }
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
                verification: todaySubmission.map(\.todayVerification) ?? verification(window: window, now: now),
                // 서버가 제출 시각을 주지 않아 인증한 날 0시를 넣는다.
                submission: todaySubmission.map { TodaySubmission(id: String($0.verificationId), submittedAt: today) }
            ),
            week: try weekly.toDomain(now: now),
            recentRecords: recent
        )
    }

    /// 구역 배정 전. 모집 중이고 아직 신청하지 않았으면 모집, 신청이 승인 대기·배정 대기면 배정 대기.
    /// 그 밖(모집이 없거나 선발되지 않음)은 홈 도메인에 맞는 상태가 없어 `UnsupportedStatusError`를 던진다.
    static func unassignedStatus(
        application: HomeDTO.Application?,
        recruitment: HomeDTO.CurrentRecruitment?
    ) throws -> HomeStatus {
        if let recruitment, recruitment.periodStatus == .open, !recruitment.alreadyApplied {
            return .recruiting(try recruitment.toDomain())
        }
        switch application?.status {
        case .pending, .approved:
            return .awaitingAssignment
        case .rejected, .unknown, nil:
            throw UnsupportedStatusError()
        }
    }

    /// 홈에 그릴 수 없는 가입 상태(모집 없음·미선발).
    struct UnsupportedStatusError: Error {}

    /// Figma `Recent section` 3건.
    static let recentRecordLimit = 3

    /// `07:20~08:10` → 분. 서버 `CleaningTimeWindow.parse`와 같이 형식이 틀리면 기본 시간.
    static func window(from cleanTime: String?) -> CleaningWindow {
        let parts = cleanTime?.split(separator: "~").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        guard parts.count == 2, let start = minuteOfDay(parts[0]), let end = minuteOfDay(parts[1]) else { return defaultWindow }
        return CleaningWindow(startMinute: start, endMinute: end)
    }

    /// 오늘 제출 전 상태. 서버가 인증 가능 여부를 주지 않아 청소 시간과 기기 시각으로 정한다.
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
        let calendar = ServerDate.calendar
        guard let monday = ServerDate.day(weekStart) else { throw APIError.decoding }
        var results: [Date: ActivityResultDTO] = [:]
        for day in days {
            guard let date = ServerDate.day(day.date) else { throw APIError.decoding }
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
    func toDomain() throws -> Recruitment {
        // 서버 학기는 `2026-2`.
        guard let semesterNumber = semester.split(separator: "-").last.flatMap({ Int($0) }) else { throw APIError.decoding }
        return Recruitment(
            semester: semesterNumber,
            capacityPerClass: maxCount,
            className: "\(grade)학년 \(classNo)반",
            appliedCount: currentApplicants
        )
    }
}

nonisolated extension HomeDTO.NoticeDetail {
    /// 홈에는 닫지 않은 최신 공지 하나만 띄우므로 늘 새 공지다.
    func toHomeNotice() throws -> Notice {
        guard let publishedAt = ServerDate.dateTime(createdAt) else { throw APIError.decoding }
        return Notice(id: String(noticeId), title: title, body: content, publishedAt: publishedAt, isNew: true)
    }
}
