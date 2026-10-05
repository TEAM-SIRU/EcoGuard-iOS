import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct RecruitmentRepositoryImplTests {
    private static let currentPath = "/api/v1/recruitments/current"
    private static let myApplicationPath = "/api/v1/applications/me"
    private static let applyPath = "/api/v1/recruitments/7/applications"
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 경로별 고정 응답. 등록하지 않은 경로는 404.
    private func makeRepository(log: RequestLog = RequestLog(), responses: [String: (Int, Data)]) -> RecruitmentRepositoryImpl {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { request in
                log.append(request)
                return responses[request.url?.path() ?? ""] ?? (404, Data())
            }
        )
        let authSession = AuthSession(
            tokenStore: InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh")),
            httpClient: httpClient
        )
        return RecruitmentRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: authSession),
            now: { Self.now }
        )
    }

    private nonisolated static func currentJSON(periodStatus: String = "OPEN", alreadyApplied: Bool = false) -> Data {
        Data("""
        {"recruitmentId":7,"semester":"2026-2","grade":2,"classNo":3,
         "period":{"start":"2026-09-01T00:00:00","end":"2026-09-04T23:59:00"},
         "periodStatus":"\(periodStatus)","maxCount":6,"currentApplicants":4,"isFull":false,"alreadyApplied":\(alreadyApplied)}
        """.utf8)
    }

    private nonisolated static func myApplicationJSON(status: String = "APPROVED", waitingForAssignment: Bool = true) -> Data {
        Data(#"{"status":"\#(status)","order":4,"waitingForAssignment":\#(waitingForAssignment)}"#.utf8)
    }

    private nonisolated static func errorJSON(_ code: String) -> Data {
        Data(#"{"code":"\#(code)","message":"메시지"}"#.utf8)
    }

    private static func kst(month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        MockRecruitmentRepository.Fixture.calendar.date(
            from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute)
        )!
    }

    @Test func fetchRecruitmentMapsCurrentRecruitment() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [Self.currentPath: (200, Self.currentJSON())])

        let detail = try #require(try await repository.fetchRecruitment())

        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path() == Self.currentPath)
        #expect(request.bearerToken == "access")
        #expect(detail.recruitment == Recruitment(semester: 2, capacityPerClass: 6, className: "2학년 3반", appliedCount: 4))
        #expect(detail.startDate == Self.kst(month: 9, day: 1))
        #expect(detail.endDate == Self.kst(month: 9, day: 4, hour: 23, minute: 59))
        #expect(detail.phase == .open)
        #expect(detail.activityWindow == RecruitmentRepositoryImpl.defaultActivityWindow)
        #expect(detail.myApplication == nil)
        // 신청하지 않았으면 내 신청을 조회하지 않는다.
        #expect(log.requests(path: Self.myApplicationPath).isEmpty)
    }

    @Test(arguments: [("UPCOMING", RecruitmentDetail.Phase.upcoming), ("OPEN", .open), ("CLOSED", .ended)])
    func periodStatusMapsToPhase(periodStatus: String, phase: RecruitmentDetail.Phase) async throws {
        let repository = makeRepository(responses: [Self.currentPath: (200, Self.currentJSON(periodStatus: periodStatus))])

        #expect(try await repository.fetchRecruitment()?.phase == phase)
    }

    @Test func alreadyAppliedFetchesMyApplication() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: true)),
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: "APPROVED", waitingForAssignment: false)),
        ])

        let detail = try #require(try await repository.fetchRecruitment())

        #expect(detail.myApplication == RecruitmentApplication(order: 4, appliedAt: Self.now, isAreaAssigned: true))
        #expect(detail.status == .applied(RecruitmentApplication(order: 4, appliedAt: Self.now, isAreaAssigned: true)))
    }

    @Test func noActiveRecruitmentIsNil() async throws {
        let repository = makeRepository(responses: [Self.currentPath: (404, Self.errorJSON("NO_ACTIVE_RECRUITMENT"))])

        #expect(try await repository.fetchRecruitment() == nil)
    }

    @Test func otherServerErrorIsThrown() async throws {
        let repository = makeRepository(responses: [Self.currentPath: (500, Self.errorJSON("INTERNAL_SERVER_ERROR"))])

        await #expect(throws: APIError.server(statusCode: 500, code: "INTERNAL_SERVER_ERROR")) {
            try await repository.fetchRecruitment()
        }
    }

    @Test func applyPostsMotivationToFetchedRecruitment() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (201, Data(#"{"applicationId":11,"status":"PENDING","order":5,"studentNumber":"2310","name":"최민준"}"#.utf8)),
        ])
        _ = try await repository.fetchRecruitment()

        let application = try await repository.apply(motivation: "깨끗한 학교")

        let request = try #require(log.requests(path: Self.applyPath).first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(request.bodyData))
        #expect(body == ["motivation": "깨끗한 학교"])
        #expect(application == RecruitmentApplication(order: 5, appliedAt: Self.now, isAreaAssigned: false))
        #expect(log.requests(path: Self.currentPath).count == 1)
    }

    /// 공고를 조회하지 않은 채 신청하면 공고 ID를 먼저 받는다.
    @Test func applyWithoutFetchLoadsRecruitmentFirst() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (201, Data(#"{"applicationId":11,"status":"PENDING","order":1,"studentNumber":null,"name":"최민준"}"#.utf8)),
        ])

        #expect(try await repository.apply(motivation: "동기").order == 1)
        #expect(log.requests.map { $0.url?.path() } == [Self.currentPath, Self.applyPath])
    }

    @Test(arguments: [
        (400, "OUT_OF_PERIOD", RecruitmentError.notInPeriod),
        (409, "RECRUITMENT_FULL", RecruitmentError.full),
    ])
    func applyErrorMapsToRecruitmentError(statusCode: Int, code: String, expected: RecruitmentError) async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (statusCode, Self.errorJSON(code)),
        ])

        do {
            _ = try await repository.apply(motivation: "동기")
            Issue.record("에러가 나야 한다")
        } catch let error as RecruitmentError {
            switch (error, expected) {
            case (.notInPeriod, .notInPeriod), (.full, .full): break
            default: Issue.record("\(error) != \(expected)")
            }
        }
    }

    @Test func alreadyAppliedErrorCarriesMyApplication() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (409, Self.errorJSON("ALREADY_APPLIED")),
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: "PENDING", waitingForAssignment: false)),
        ])

        do {
            _ = try await repository.apply(motivation: "동기")
            Issue.record("에러가 나야 한다")
        } catch RecruitmentError.alreadyApplied(let application) {
            #expect(application == RecruitmentApplication(order: 4, appliedAt: Self.now, isAreaAssigned: false))
        }
    }

    /// 앱에 대응하는 상태가 없는 서버 에러(다른 반 공고 등)는 그대로 올린다.
    @Test func unmappedApplyErrorIsThrown() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (403, Self.errorJSON("CLASS_MISMATCH")),
        ])

        await #expect(throws: APIError.server(statusCode: 403, code: "CLASS_MISMATCH")) {
            try await repository.apply(motivation: "동기")
        }
    }

    @Test func noApplicationIsNil() async throws {
        let repository = makeRepository(responses: [Self.myApplicationPath: (404, Self.errorJSON("NO_APPLICATION"))])

        #expect(try await repository.fetchMyApplication() == nil)
    }

    /// 승인 전(PENDING)에는 서버가 배정 대기를 false로 주지만 배정된 것이 아니다.
    @Test(arguments: [
        ("PENDING", false, false),
        ("APPROVED", true, false),
        ("APPROVED", false, true),
    ])
    func myApplicationAreaAssignment(status: String, waitingForAssignment: Bool, isAreaAssigned: Bool) async throws {
        let repository = makeRepository(responses: [
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: status, waitingForAssignment: waitingForAssignment)),
        ])

        #expect(try await repository.fetchMyApplication()?.isAreaAssigned == isAreaAssigned)
    }

    @Test func rejectedApplicationIsNil() async throws {
        let repository = makeRepository(responses: [Self.myApplicationPath: (200, Self.myApplicationJSON(status: "REJECTED"))])

        #expect(try await repository.fetchMyApplication() == nil)
    }

    /// 서버가 신청 시각을 내려주면 대체값 대신 쓴다.
    @Test func myApplicationUsesServerAppliedAtWhenPresent() async throws {
        let json = Data(#"{"status":"APPROVED","order":4,"waitingForAssignment":true,"appliedAt":"2026-09-01T12:34:00"}"#.utf8)
        let repository = makeRepository(responses: [Self.myApplicationPath: (200, json)])

        #expect(try await repository.fetchMyApplication()?.appliedAt == Self.kst(month: 9, day: 1, hour: 12, minute: 34))
    }
}

struct ServerDateTimeTests {
    @Test(arguments: [
        ("2026-09-01T12:34", 0.0),
        ("2026-09-01T12:34:00", 0.0),
        ("2026-09-01T12:34:56", 56.0),
        ("2026-09-01T12:34:56.5", 56.5),
        ("2026-09-01T12:34:56.250000", 56.25),
    ])
    func parsesLocalDateTimeAsKST(string: String, seconds: Double) throws {
        // 2026-09-01 12:34 KST = 03:34 UTC
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-09-01T03:34:00Z")).addingTimeInterval(seconds)
        #expect(try ServerDateTime.date(from: string) == expected)
    }

    @Test(arguments: ["2026-09-01", "2026-09-01T12:34:00Z", ""])
    func rejectsOtherFormats(string: String) {
        #expect(throws: APIError.decoding) { try ServerDateTime.date(from: string) }
    }

    @Test func parsesCleanTime() {
        #expect(ServerDateTime.minuteRange(from: "07:20~08:10")! == (440, 490))
        #expect(ServerDateTime.minuteRange(from: "8:00 - 8:10")! == (480, 490))
        #expect(ServerDateTime.minuteRange(from: "아침") == nil)
    }
}
