import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct HomeRepositoryImplTests {
    private enum Path {
        static let assignment = "/api/v1/assignments/me"
        static let weekly = "/api/v1/service-times/me/weekly"
        static let verifications = "/api/v1/verifications/me"
        static let application = "/api/v1/applications/me"
        static let recruitment = "/api/v1/recruitments/current"
        static let notices = "/api/v1/notices"
        static let notice = "/api/v1/notices/7"
    }

    /// 2026-09-29(화) 09:00 KST.
    private static let now = PathStub.date(2026, 9, 29, 9)

    private static let assignmentJSON = """
    {"areaId":3,"areaName":"본관 계단 A","description":null,"cleanTime":"08:00~08:10",
     "mapCoordinates":{"x":0,"y":0},"members":[{"studentId":1,"studentNumber":"2301","name":"김학생"}]}
    """

    private static let weeklyJSON = """
    {"weekStart":"2026-09-28","weekEnd":"2026-10-02","completedDays":1,"requiredDays":5,
     "days":[{"date":"2026-09-28","result":"APPROVED"},{"date":"2026-09-29","result":"REJECTED"},
             {"date":"2026-09-30","result":"UPCOMING"}]}
    """

    private static let verificationsJSON = """
    [{"verificationId":41,"photoUrl":"/f/41.jpg","date":"2026-09-29","areaName":"본관 계단 A","reviewStatus":"REJECTED","failReasons":["쓰레기가 보여요","구역이 잘렸어요"]},
     {"verificationId":40,"photoUrl":"/f/40.jpg","date":"2026-09-28","areaName":"본관 계단 A","reviewStatus":"APPROVED","failReasons":null},
     {"verificationId":39,"photoUrl":"/f/39.jpg","date":"2026-09-25","areaName":"본관 계단 A","reviewStatus":"MANUAL_REVIEW","failReasons":null},
     {"verificationId":38,"photoUrl":"/f/38.jpg","date":"2026-09-24","areaName":"본관 계단 A","reviewStatus":"REJECTED","failReasons":["흐려요"]},
     {"verificationId":37,"photoUrl":"/f/37.jpg","date":"2026-09-23","areaName":"본관 계단 A","reviewStatus":"APPROVED","failReasons":null}]
    """

    private static let noticesJSON = """
    [{"noticeId":7,"title":"10월 안내","createdAt":"2026-09-28T17:30:00.123456"},{"noticeId":6,"title":"9월 안내","createdAt":"2026-09-01T09:00:00"}]
    """

    private static let noticeJSON = """
    {"noticeId":7,"title":"10월 안내","content":"매일 **08:00**에 청소해요","createdAt":"2026-09-28T17:30:00.123456","previousNoticeId":6,"nextNoticeId":null}
    """

    private static var activeResponses: [String: (Int, String)] {
        [
            Path.assignment: (200, assignmentJSON),
            Path.weekly: (200, weeklyJSON),
            Path.verifications: (200, verificationsJSON),
            Path.notices: (200, noticesJSON),
            Path.notice: (200, noticeJSON)
        ]
    }

    private func makeRepository(
        log: RequestLog = RequestLog(),
        responses: [String: (Int, String)],
        defaults: UserDefaults? = nil,
        now: Date? = nil
    ) throws -> HomeRepositoryImpl {
        let now = now ?? Self.now
        return HomeRepositoryImpl(
            apiClient: PathStub.makeClient(log: log, responses: responses),
            defaults: try defaults ?? Self.makeDefaults(),
            now: { now }
        )
    }

    @Test func activeHomeCombinesAssignmentWeekVerificationsAndNotice() async throws {
        let log = RequestLog()
        let repository = try makeRepository(log: log, responses: Self.activeResponses)

        let summary = try await repository.fetchHome()

        for path in [Path.assignment, Path.weekly, Path.verifications, Path.notices, Path.notice] {
            let request = try #require(log.requests(path: path).first, "\(path) 요청 없음")
            #expect(request.httpMethod == "GET")
            #expect(request.bearerToken == PathStub.tokens.accessToken)
        }
        #expect(log.requests(path: Path.application).isEmpty)

        guard case .active(let cleaning) = summary.status else {
            Issue.record("활동 중이어야 한다: \(summary.status)")
            return
        }
        #expect(cleaning.today == TodayCleaning(
            area: "본관 계단 A",
            window: CleaningWindow(startMinute: 480, endMinute: 490),
            verification: .rejected(reason: "쓰레기가 보여요\n구역이 잘렸어요"),
            submission: TodaySubmission(id: "41", submittedAt: PathStub.date(2026, 9, 29))
        ))
        #expect(cleaning.week.days == [
            .init(weekday: 2, isToday: false, isCompleted: true),
            .init(weekday: 3, isToday: true, isCompleted: false),
            .init(weekday: 4, isToday: false, isCompleted: false),
            .init(weekday: 5, isToday: false, isCompleted: false),
            .init(weekday: 6, isToday: false, isCompleted: false)
        ])
        // 오늘 것은 빼고 최근 3건.
        #expect(cleaning.recentRecords == [
            CleaningRecord(id: "40", date: PathStub.date(2026, 9, 28), cleanedAt: nil, area: "본관 계단 A", result: .approved(earnedMinutes: 10)),
            CleaningRecord(id: "39", date: PathStub.date(2026, 9, 25), cleanedAt: nil, area: "본관 계단 A", result: .processing),
            CleaningRecord(id: "38", date: PathStub.date(2026, 9, 24), cleanedAt: nil, area: "본관 계단 A", result: .rejected)
        ])
        #expect(summary.notice == Notice(
            id: "7",
            title: "10월 안내",
            body: "매일 **08:00**에 청소해요",
            publishedAt: PathStub.date(2026, 9, 28, 17, 30).addingTimeInterval(0.123456),
            isNew: true
        ))
    }

    @Test(arguments: [
        ("PROCESSING", TodayVerification.aiReviewing(submittedAt: nil)),
        ("MANUAL_REVIEW", .teacherReviewing(submittedAt: nil)),
        ("APPROVED", .approved(earnedMinutes: 10))
    ])
    func todayStatusFollowsVerification(status: String, expected: TodayVerification) async throws {
        var responses = Self.activeResponses
        responses[Path.verifications] = (200, #"[{"verificationId":41,"photoUrl":"/f.jpg","date":"2026-09-29","areaName":"A","reviewStatus":"\#(status)","failReasons":null}]"#)
        let repository = try makeRepository(responses: responses)

        guard case .active(let cleaning) = try await repository.fetchHome().status else {
            Issue.record("활동 중이어야 한다")
            return
        }
        #expect(cleaning.today.verification == expected)
        #expect(cleaning.today.submission?.id == "41")
        #expect(cleaning.recentRecords.isEmpty)
    }

    /// 오늘 제출 전: 서버가 인증 가능 여부를 주지 않아 청소 시간(08:00~08:10)과 기기 시각으로 정한다.
    @Test(arguments: [
        // 화 07:59 → 오늘 08:00
        (PathStub.date(2026, 9, 29, 7, 59), TodayVerification.notOpenYet(opensAt: PathStub.date(2026, 9, 29, 8))),
        // 화 08:05 → 08:10까지
        (PathStub.date(2026, 9, 29, 8, 5), .open(deadline: PathStub.date(2026, 9, 29, 8, 10))),
        // 화 08:10 정각은 마감
        (PathStub.date(2026, 9, 29, 8, 10), .notOpenYet(opensAt: PathStub.date(2026, 9, 30, 8))),
        // 금 09:00 → 월 08:00
        (PathStub.date(2026, 10, 2, 9), .notOpenYet(opensAt: PathStub.date(2026, 10, 5, 8))),
        // 토 → 월 08:00
        (PathStub.date(2026, 10, 3, 7), .notOpenYet(opensAt: PathStub.date(2026, 10, 5, 8)))
    ])
    func todayWithoutSubmissionFollowsCleaningWindow(now: Date, expected: TodayVerification) async throws {
        var responses = Self.activeResponses
        responses[Path.verifications] = (200, "[]")
        let repository = try makeRepository(responses: responses, now: now)

        guard case .active(let cleaning) = try await repository.fetchHome().status else {
            Issue.record("활동 중이어야 한다")
            return
        }
        #expect(cleaning.today.verification == expected)
        #expect(cleaning.today.submission == nil)
    }

    @Test(arguments: [nil, "아침", "08:00-08:10", "25:00~26:00"])
    func missingOrMalformedCleanTimeUsesServerDefault(cleanTime: String?) {
        #expect(HomeMapper.window(from: cleanTime) == CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10))
    }

    @Test func recruitingWhenUnassignedAndRecruitmentOpen() async throws {
        let log = RequestLog()
        let repository = try makeRepository(log: log, responses: [
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.weekly: (200, #"{"weekStart":"2026-09-28","weekEnd":"2026-10-02","completedDays":0,"requiredDays":5,"days":[]}"#),
            Path.verifications: (200, "[]"),
            Path.application: (404, PathStub.error("NO_APPLICATION")),
            Path.recruitment: (200, Self.recruitmentJSON(status: "OPEN", alreadyApplied: false)),
            Path.notices: (200, "[]")
        ])

        let summary = try await repository.fetchHome()

        #expect(summary == HomeSummary(
            status: .recruiting(Recruitment(semester: 2, capacityPerClass: 6, className: "2학년 3반", appliedCount: 4)),
            notice: nil
        ))
        #expect(log.requests(path: Path.recruitment).first?.httpMethod == "GET")
        #expect(log.requests(path: Path.notice).isEmpty)
    }

    @Test(arguments: ["PENDING", "APPROVED"])
    func awaitingAssignmentAfterApplying(status: String) async throws {
        let repository = try makeRepository(responses: [
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.application: (200, #"{"status":"\#(status)","order":3,"waitingForAssignment":true}"#),
            Path.recruitment: (200, Self.recruitmentJSON(status: "OPEN", alreadyApplied: true))
        ])

        #expect(try await repository.fetchHome().status == .awaitingAssignment)
    }

    /// 모집이 없거나 선발되지 않은 학생은 홈 도메인에 맞는 상태가 없다(서버·기획 요청 목록).
    @Test func unsupportedWhenNotSelectedAndNoOpenRecruitment() async throws {
        let repository = try makeRepository(responses: [
            Path.assignment: (404, PathStub.error("NO_ASSIGNMENT")),
            Path.application: (200, #"{"status":"REJECTED","order":9,"waitingForAssignment":false}"#),
            Path.recruitment: (404, PathStub.error("NO_ACTIVE_RECRUITMENT"))
        ])

        await #expect(throws: HomeMapper.UnsupportedStatusError.self) {
            try await repository.fetchHome()
        }
    }

    /// 404라도 "아직 없음" 코드가 아니면 에러다.
    @Test(arguments: [(404, "USER_NOT_FOUND"), (500, "INTERNAL_SERVER_ERROR")])
    func assignmentErrorsAreThrown(statusCode: Int, code: String) async throws {
        var responses = Self.activeResponses
        responses[Path.assignment] = (statusCode, PathStub.error(code))
        let repository = try makeRepository(responses: responses)

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.fetchHome()
        }
    }

    @Test func weeklyFailureFailsActiveHome() async throws {
        var responses = Self.activeResponses
        responses[Path.weekly] = (500, PathStub.error("INTERNAL_SERVER_ERROR"))
        let repository = try makeRepository(responses: responses)

        await #expect(throws: APIError.server(statusCode: 500, code: "INTERNAL_SERVER_ERROR")) {
            try await repository.fetchHome()
        }
    }

    /// 공지는 홈 본문이 아니라서 실패해도 홈은 보여 준다.
    @Test func noticeFailureStillLoadsHome() async throws {
        var responses = Self.activeResponses
        responses[Path.notices] = (500, PathStub.error("INTERNAL_SERVER_ERROR"))
        let repository = try makeRepository(responses: responses)

        let summary = try await repository.fetchHome()

        #expect(summary.notice == nil)
        guard case .active = summary.status else {
            Issue.record("활동 중이어야 한다")
            return
        }
    }

    @Test func dismissedNoticeIsNotShownAgain() async throws {
        let defaults = try Self.makeDefaults()
        let log = RequestLog()
        let repository = try makeRepository(log: log, responses: Self.activeResponses, defaults: defaults)

        await repository.dismissNotice(id: "7")
        let summary = try await repository.fetchHome()

        #expect(summary.notice == nil)
        #expect(log.requests(path: Path.notice).isEmpty)
        // 다른 저장소 인스턴스(앱 재시작)에서도 유지된다.
        let reopened = try makeRepository(responses: Self.activeResponses, defaults: defaults)
        #expect(try await reopened.fetchHome().notice == nil)
    }

    nonisolated private static func recruitmentJSON(status: String, alreadyApplied: Bool) -> String {
        """
        {"recruitmentId":1,"semester":"2026-2","grade":2,"classNo":3,
         "period":{"start":"2026-09-01T00:00:00","end":"2026-09-10T23:59:59"},
         "periodStatus":"\(status)","maxCount":6,"currentApplicants":4,"isFull":false,"alreadyApplied":\(alreadyApplied)}
        """
    }

    private static func makeDefaults() throws -> UserDefaults {
        let suiteName = "HomeRepositoryImplTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
