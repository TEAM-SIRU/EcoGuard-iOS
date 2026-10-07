import Foundation

/// 서버 없이 앱을 돌릴 때 Mock 저장소들이 같이 쓰는 인메모리 상태. 실제 서버처럼 여러 화면이 한 곳의 데이터를 본다.
/// 홈·활동 기록·마이페이지·인증 결과·이의신청·모집이 같은 날짜와 기록을 쓰고,
/// 인증 제출·모집 신청·이의신청 제출이 여기에 남아 다른 화면(홈으로 돌아왔을 때 등)에도 보인다.
///
/// 날짜는 `now`(기기 시계, 테스트는 고정 시계) 기준이다. 주말이면 그 주 금요일을 오늘 수업일로 둔다.
/// 기록은 오늘 수업일에서 거꾸로 센 수업일 순서(`Pattern`)로 만들어, 어느 날 실행해도 화면 구성이 같다.
final class MockStore {
    let now: () -> Date
    /// 홈 상태. 신청·인증 제출에 따라 바뀐다.
    private(set) var homeScenario: MockHomeRepository.Scenario
    /// 내 모집 신청. 신청하면 생긴다.
    private(set) var application: RecruitmentApplication?
    /// 이번 실행에서 오늘 인증을 제출한 시각. 있으면 오늘 상태는 AI 검수 중이다.
    private(set) var todaySubmittedAt: Date?
    /// 이번 실행에서 보낸 이의신청(최신순).
    private(set) var submittedAppeals: [Appeal] = []
    /// 활동 중일 때 배정된 청소 구역.
    let zoneCode: CleaningZoneCode

    /// - Parameters:
    ///   - homeScenario: 홈 상태. 활동 중·배정 대기·활동 제외면 이미 신청한 학생이다.
    ///   - recruitmentScenario: `.applied`면 홈 상태와 상관없이 신청한 학생이다.
    ///   - zoneCode: 활동 중일 때 배정된 청소 구역.
    init(
        homeScenario: MockHomeRepository.Scenario = .notSubmitted,
        recruitmentScenario: MockRecruitmentRepository.Scenario = .open,
        zoneCode: CleaningZoneCode = MockCleaningAreaRepository.Fixture.zoneCode,
        now: @escaping () -> Date = Date.init
    ) {
        self.now = now
        self.homeScenario = homeScenario
        self.zoneCode = zoneCode
        if homeScenario.hasApplied || recruitmentScenario == .applied {
            application = RecruitmentApplication(
                order: Self.seededApplicationOrder,
                appliedAt: Self.at(hour: 12, minute: 34, on: Self.recruitmentPeriod(.open, now: now()).start),
                isAreaAssigned: homeScenario.isActive
            )
        }
    }

    // MARK: - 날짜

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    /// 오늘 수업일(KST 0시). 주말이면 그 주 금요일.
    var schoolToday: Date {
        Self.schoolDay(onOrBefore: now())
    }

    /// `date`가 속한 날이나 그 전의 가장 가까운 평일(KST 0시).
    static func schoolDay(onOrBefore date: Date) -> Date {
        var day = calendar.startOfDay(for: date)
        while calendar.isDateInWeekend(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return day
    }

    static func at(hour: Int, minute: Int, on day: Date) -> Date {
        calendar.date(byAdding: .minute, value: hour * 60 + minute, to: calendar.startOfDay(for: day)) ?? day
    }

    /// 홈·청소 인증·활동 기록과 같은 `verification-YYYYMMDD` 체계.
    static func verificationID(for day: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "verification-%04d%02d%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    // MARK: - 오늘 인증

    /// 오늘 인증 상태. 이번 실행에서 제출했으면 AI 검수 중이다. 활동 중이 아니면 nil.
    func todayVerification(deadline: Date) -> TodayVerification? {
        guard homeScenario.isActive else { return nil }
        if let todaySubmittedAt {
            return .aiReviewing(submittedAt: todaySubmittedAt)
        }
        return switch homeScenario {
        case .notSubmitted: .open(deadline: deadline)
        case .aiReviewing: .aiReviewing(submittedAt: todayFixedSubmittedAt)
        case .teacherReviewing: .teacherReviewing(submittedAt: todayFixedSubmittedAt)
        case .approved: .approved(earnedMinutes: ActivityRecord.minutesPerApproval)
        case .rejected: .rejected(reason: MockVerificationResultRepository.Fixture.rejectionReason.title)
        case .notOpenYet: .notOpenYet(opensAt: MockHomeRepository.Fixture.opensAt(onDayOf: schoolToday))
        case .vacation: .vacation
        case .recruiting, .awaitingAssignment, .notSelected, .notRecruiting, .excluded, .failure: nil
        }
    }

    /// 오늘 낸 인증의 결과 상태와 제출 시각. 아직 내지 않았으면 nil.
    var todayResult: (status: VerificationResult.Status, submittedAt: Date)? {
        guard homeScenario.isActive else { return nil }
        if let todaySubmittedAt {
            return (.processing, todaySubmittedAt)
        }
        let status: VerificationResult.Status? = switch homeScenario {
        case .aiReviewing: .processing
        case .teacherReviewing: .manualReview
        case .approved: .approved
        case .rejected: .rejected
        default: nil
        }
        return status.map { ($0, todayFixedSubmittedAt) }
    }

    var todayVerificationID: String {
        Self.verificationID(for: schoolToday)
    }

    /// 시나리오로 정한 오늘 제출 시각. Figma `오늘 08:04`.
    private var todayFixedSubmittedAt: Date {
        Self.at(hour: 8, minute: 4, on: schoolToday)
    }

    /// 청소 인증 사진을 받았다. 홈·기록·인증 결과가 AI 검수 중으로 바뀐다.
    func recordVerificationSubmitted(at date: Date) {
        if homeScenario.isActive {
            todaySubmittedAt = date
        }
    }

    // MARK: - 활동 기록

    /// 오늘 수업일에서 거꾸로 센 수업일 순서(0 = 오늘)마다 정해 둔 결과. 나머지는 승인이다.
    /// Figma `02 홈` 최근 기록(승인·승인·반려)과 `09 이의신청`(반려·검토 중·승인 이의신청)을 따른다.
    /// 서버는 검토 중인 이의신청이 있는 인증에 다시 받지 않아서, 다시 이의신청할 수 있는 반려(`rejectedOffset`)와
    /// 검토 중인 반려(`pendingAppealOffset`)를 다른 인증으로 둔다.
    enum Pattern {
        static let rejectedOffset = 3
        static let appealApprovedOffset = 4
        static let pendingAppealOffset = 6
        static let notSubmittedOffset = 8
    }

    /// 활동 기록이 있는 학생(활동 중이거나 활동했다가 제외됨).
    var hasActivity: Bool {
        homeScenario.isActive || homeScenario == .excluded
    }

    /// `month`의 기록(최신순). 기록은 오늘(기기 시계)이 속한 달과 그 전 달에만 있다.
    func records(in month: YearMonth) -> [ActivityRecord] {
        allRecords.filter {
            let components = Self.calendar.dateComponents([.year, .month], from: $0.date)
            return components.year == month.year && components.month == month.month
        }
    }

    /// 오늘(기기 시계)이 속한 달.
    var currentMonth: YearMonth {
        let components = Self.calendar.dateComponents([.year, .month], from: now())
        return YearMonth(year: components.year ?? 0, month: components.month ?? 0)
    }

    /// 전 달 1일부터 오늘 수업일까지 평일마다 하나씩(최신순). 오늘은 제출했을 때만 있다.
    var allRecords: [ActivityRecord] {
        guard hasActivity else { return [] }
        let today = schoolToday
        let currentMonthStart = Self.calendar.date(from: Self.calendar.dateComponents([.year, .month], from: now())) ?? today
        let start = Self.calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        var records: [ActivityRecord] = []
        var day = today
        var offset = 0
        while day >= start {
            if !Self.calendar.isDateInWeekend(day) {
                if let record = record(on: day, offset: offset) {
                    records.append(record)
                }
                offset += 1
            }
            guard let previous = Self.calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return records
    }

    private func record(on day: Date, offset: Int) -> ActivityRecord? {
        let result: ActivityRecord.Result
        let submittedAt: Date?
        if offset == 0 {
            guard let today = todayResult else { return nil }
            result = switch today.status {
            case .processing, .manualReview: .reviewing
            case .approved: .approved
            case .rejected: .rejected
            }
            submittedAt = today.submittedAt
        } else {
            result = switch offset {
            case Pattern.rejectedOffset, Pattern.pendingAppealOffset: .rejected
            case Pattern.notSubmittedOffset: .notSubmitted
            default: .approved
            }
            // 반려된 인증은 Figma `08:04`. 나머지는 08:00~08:09에 흩어 둔다.
            let minute = result == .rejected ? 4 : Self.calendar.component(.day, from: day) % 10
            submittedAt = result == .notSubmitted ? nil : Self.at(hour: 8, minute: minute, on: day)
        }
        return ActivityRecord(
            id: "record-\(Self.verificationID(for: day).dropFirst("verification-".count))",
            date: day,
            area: MockHomeRepository.Fixture.area,
            result: result,
            submittedAt: submittedAt,
            verificationID: result == .notSubmitted ? nil : Self.verificationID(for: day),
            earnedMinutes: result == .approved ? ActivityRecord.minutesPerApproval : 0,
            isAppealApproved: offset == Pattern.appealApprovedOffset
        )
    }

    /// 오늘 수업일에서 `offset`번째 전 수업일.
    func schoolDay(offset: Int) -> Date {
        var day = schoolToday
        var remaining = offset
        while remaining > 0 {
            day = Self.calendar.date(byAdding: .day, value: -1, to: day) ?? day
            if !Self.calendar.isDateInWeekend(day) {
                remaining -= 1
            }
        }
        return day
    }

    /// 인증 ID로 찾은 기록의 결과 상태와 제출 시각. 인증 결과 Mock이 같은 상태를 돌려줄 때 쓴다. 모르는 ID면 nil.
    func submittedRecord(verificationID: String) -> (status: VerificationResult.Status, submittedAt: Date)? {
        if verificationID == todayVerificationID, let todayResult {
            return todayResult
        }
        guard let record = allRecords.first(where: { $0.verificationID == verificationID }), let submittedAt = record.submittedAt else { return nil }
        let status: VerificationResult.Status? = switch record.result {
        case .reviewing: .processing
        case .approved: .approved
        case .rejected: .rejected
        case .notSubmitted: nil
        }
        return status.map { ($0, submittedAt) }
    }

    // MARK: - 홈

    /// 홈 최근 기록. 오늘 전 제출한 기록 3건.
    var recentCleaningRecords: [CleaningRecord] {
        let today = schoolToday
        return allRecords
            .filter { $0.date < today && $0.result != .notSubmitted }
            .prefix(3)
            .map { record in
                let result: CleaningRecord.Result = switch record.result {
                case .approved: .approved(earnedMinutes: record.earnedMinutes)
                case .rejected, .notSubmitted: .rejected
                case .reviewing: .processing
                }
                return CleaningRecord(id: record.id, date: record.date, cleanedAt: record.submittedAt, area: record.area ?? "", result: result)
            }
    }

    /// 오늘 수업일이 속한 주(월~금). 승인된 날을 완료로 칠한다.
    var week: WeeklyCleaning {
        let today = schoolToday
        let weekday = Self.calendar.component(.weekday, from: today)
        let approvedDays = Set(allRecords.filter { $0.result == .approved }.map(\.date))
        return WeeklyCleaning(days: (2...6).map { day in
            let date = Self.calendar.date(byAdding: .day, value: day - weekday, to: today) ?? today
            return WeeklyCleaning.Day(weekday: day, isToday: day == weekday, isCompleted: approvedDays.contains(date))
        })
    }

    // MARK: - 마이페이지

    /// 이번 달(기기 시계) 승인 횟수.
    var monthlyApprovedCount: Int {
        records(in: currentMonth).filter { $0.result == .approved }.count
    }

    /// 이번 달(기기 시계) 인정된 활동 시간(분). 활동 기록 화면 합계와 같다.
    var monthlyActivityMinutes: Int {
        records(in: currentMonth).reduce(0) { $0 + $1.earnedMinutes }
    }

    // MARK: - 모집

    /// 이미 신청한 학생은 반에서 4번째로 신청했다(Figma `4번째로 신청했어요`).
    static let seededApplicationOrder = 4

    /// 공고 기간. 오늘 기준으로 신청 중이면 사흘 전(주말이면 그 전 금요일) ~ 나흘 뒤, 예정이면 1주 뒤부터, 끝났으면 2주 전까지.
    static func recruitmentPeriod(_ phase: RecruitmentDetail.Phase, now: Date) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)
        let (startOffset, endOffset) = switch phase {
        case .open: (-3, 4)
        case .upcoming: (7, 11)
        case .ended: (-18, -14)
        }
        // 신청 중인 공고는 평일에 시작한 것으로 둔다(이미 신청한 학생의 신청 시각이 그날 12:34).
        let startDay = calendar.date(byAdding: .day, value: startOffset, to: today) ?? today
        let start = phase == .open ? schoolDay(onOrBefore: startDay) : startDay
        let endDay = calendar.date(byAdding: .day, value: endOffset, to: today) ?? today
        return (start, at(hour: 23, minute: 59, on: endDay))
    }

    /// 모집 신청을 받았다. 모집 중이던 홈은 배정 대기가 되고, 구역까지 배정됐으면 활동 중이 된다.
    func recordApplication(appliedCount: Int, isAreaAssigned: Bool) -> RecruitmentApplication {
        if let application { return application }
        let application = RecruitmentApplication(order: appliedCount + 1, appliedAt: now(), isAreaAssigned: isAreaAssigned)
        self.application = application
        if !homeScenario.hasApplied {
            homeScenario = isAreaAssigned ? .notSubmitted : .awaitingAssignment
        }
        return application
    }

    // MARK: - 이의신청

    /// 기록에 맞춘 이의신청 내역(최신순). 반려된 인증(수업일 6일 전)에 검토 중, 반려된 인증(3일 전)에 반려, 4일 전 인증에 승인.
    var appeals: [Appeal] {
        submittedAppeals + seededAppeals
    }

    private var seededAppeals: [Appeal] {
        guard hasActivity else { return [] }
        let rejectedDay = schoolDay(offset: Pattern.rejectedOffset)
        let pendingDay = schoolDay(offset: Pattern.pendingAppealOffset)
        let approvedDay = schoolDay(offset: Pattern.appealApprovedOffset)
        let fixture = MockAppealRepository.Fixture.self
        func appeal(_ base: Appeal, day: Date, submittedOn submittedDay: Date) -> Appeal {
            let submittedTime = Self.calendar.dateComponents(in: Self.calendar.timeZone, from: base.submittedAt)
            return Appeal(
                id: base.id,
                verificationID: Self.verificationID(for: day),
                verifiedAt: verifiedAt(Self.verificationID(for: day)) ?? day,
                round: 1,
                submittedAt: Self.at(hour: submittedTime.hour ?? 12, minute: submittedTime.minute ?? 0, on: submittedDay),
                status: base.status,
                earnedMinutes: base.earnedMinutes,
                teacherReply: base.teacherReply,
                photoURLs: base.photoURLs
            )
        }
        return [
            appeal(fixture.reviewing, day: pendingDay, submittedOn: schoolDay(offset: 1)),
            appeal(fixture.rejected, day: rejectedDay, submittedOn: rejectedDay),
            appeal(fixture.approved, day: approvedDay, submittedOn: approvedDay)
        ]
    }

    /// 작성 화면 기본 대상. 반려된 인증(수업일 3일 전).
    var appealTarget: AppealTarget {
        let id = Self.verificationID(for: schoolDay(offset: Pattern.rejectedOffset))
        return AppealTarget(
            verificationID: id,
            verifiedAt: verifiedAt(id) ?? schoolDay(offset: Pattern.rejectedOffset),
            rejectionReason: MockAppealRepository.Fixture.target.rejectionReason
        )
    }

    /// 인증을 낸 시각. 이의신청 대상 표시에 쓴다. 모르는 ID면 nil.
    func verifiedAt(_ verificationID: String) -> Date? {
        submittedRecord(verificationID: verificationID)?.submittedAt
    }

    /// `verificationID`에 검토 중인 이의신청. 있으면 서버처럼 새 이의신청을 받지 않는다.
    func pendingAppeal(for verificationID: String) -> Appeal? {
        appeals.first { $0.verificationID == verificationID && $0.status == .reviewing }
    }

    /// 이의신청을 받았다. 같은 인증에 몇 번째인지 내역으로 센다.
    func recordAppeal(_ draft: AppealDraft) -> Appeal {
        let round = appeals.filter { $0.verificationID == draft.verificationID }.count + 1
        let appeal = Appeal(
            id: "appeal-\(draft.requestID)",
            verificationID: draft.verificationID,
            verifiedAt: verifiedAt(draft.verificationID) ?? now(),
            round: round,
            submittedAt: now(),
            status: .reviewing,
            earnedMinutes: nil,
            teacherReply: nil,
            photoURLs: []
        )
        submittedAppeals.insert(appeal, at: 0)
        return appeal
    }
}

extension MockHomeRepository.Scenario {
    /// 구역을 배정받아 활동 중인 상태.
    var isActive: Bool {
        switch self {
        case .notSubmitted, .aiReviewing, .approved, .rejected, .teacherReviewing, .notOpenYet, .vacation: true
        case .recruiting, .awaitingAssignment, .notSelected, .notRecruiting, .excluded, .failure: false
        }
    }

    /// 모집에 신청한 학생의 상태(활동 중·배정 대기·활동 제외).
    var hasApplied: Bool {
        isActive || self == .awaitingAssignment || self == .excluded
    }
}
