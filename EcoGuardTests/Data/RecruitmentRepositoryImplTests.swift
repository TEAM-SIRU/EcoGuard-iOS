import Foundation
import os
import Testing
@testable import EcoGuard

@MainActor
struct RecruitmentRepositoryImplTests {
    private nonisolated static let currentPath = "/api/v1/recruitments/current"
    private nonisolated static let myApplicationPath = "/api/v1/applications/me"
    private nonisolated static let applyPath = "/api/v1/recruitments/7/applications"
    /// 신청 시각 `2026-09-01T12:34:00`(KST).
    private static let appliedAt = MockRecruitmentRepository.Fixture.calendar.date(
        from: DateComponents(year: 2026, month: 9, day: 1, hour: 12, minute: 34)
    )!

    /// 경로별 고정 응답. 등록하지 않은 경로는 404.
    private func makeRepository(
        log: RequestLog = RequestLog(),
        currentUser: CurrentUser? = MockCurrentUserRepository.user,
        responses: [String: (Int, Data)]
    ) -> RecruitmentRepositoryImpl {
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
            currentUserRepository: MockCurrentUserRepository(user: currentUser)
        )
    }

    private nonisolated static func currentJSON(
        id: Int = 7,
        semester: String = "2026-2",
        periodStatus: String = "OPEN",
        activityTime: String = #"{"start":"07:20:00","end":"08:10:00"}"#,
        alreadyApplied: Bool = false
    ) -> Data {
        Data("""
        {"recruitmentId":\(id),"semester":"\(semester)","grade":2,"classNo":3,
         "period":{"start":"2026-09-01T00:00:00","end":"2026-09-04T23:59:00"},"activityTime":\(activityTime),
         "periodStatus":"\(periodStatus)","maxCount":6,"currentApplicants":4,"isFull":false,"alreadyApplied":\(alreadyApplied)}
        """.utf8)
    }

    private nonisolated static func myApplicationJSON(status: String = "APPROVED", waitingForAssignment: Bool = true) -> Data {
        Data(#"{"status":"\#(status)","order":4,"appliedAt":"2026-09-01T12:34:00","waitingForAssignment":\#(waitingForAssignment)}"#.utf8)
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
        #expect(detail.activityWindow == CleaningWindow(startMinute: 7 * 60 + 20, endMinute: 8 * 60 + 10))
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

        #expect(detail.myApplication == RecruitmentApplication(order: 4, appliedAt: Self.appliedAt, isAreaAssigned: true))
        #expect(detail.status == .applied(RecruitmentApplication(order: 4, appliedAt: Self.appliedAt, isAreaAssigned: true)))
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
            Self.applyPath: (201, Data(#"{"applicationId":11,"status":"APPROVED","order":5,"studentNumber":"2310","name":"최민준","appliedAt":"2026-09-01T12:34:00"}"#.utf8)),
        ])
        _ = try await repository.fetchRecruitment()

        let application = try await repository.apply(motivation: "깨끗한 학교")

        let request = try #require(log.requests(path: Self.applyPath).first)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(request.bodyData))
        #expect(body == ["motivation": "깨끗한 학교"])
        #expect(application == RecruitmentApplication(order: 5, appliedAt: Self.appliedAt, isAreaAssigned: false))
        #expect(log.requests(path: Self.currentPath).count == 1)
    }

    /// 공고를 조회하지 않은 채 신청하면 공고 ID를 먼저 받는다.
    @Test func applyWithoutFetchLoadsRecruitmentFirst() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (201, Data(#"{"applicationId":11,"status":"APPROVED","order":1,"studentNumber":null,"name":"최민준","appliedAt":"2026-09-01T12:34:00"}"#.utf8)),
        ])

        #expect(try await repository.apply(motivation: "동기").order == 1)
        #expect(log.requests.map { $0.url?.path() } == [Self.currentPath, Self.applyPath])
    }

    @Test(arguments: [
        (400, "OUT_OF_PERIOD", RecruitmentError.notInPeriod),
        (409, "RECRUITMENT_FULL", RecruitmentError.full),
    ])
    func applyErrorMapsToRecruitmentError(statusCode: Int, code: String, expected: RecruitmentError) async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
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
        // 방금 조회한 공고면 다시 조회·재전송하지 않는다.
        #expect(log.requests(path: Self.applyPath).count == 1)
        #expect(log.requests(path: Self.currentPath).count == 1)
    }

    /// 들고 있던 공고를 다시 조회했는데 같은 공고면 다시 보내지 않고 에러를 알린다.
    @Test func sameRecruitmentAfterRefetchIsNotResent() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (409, Self.errorJSON("RECRUITMENT_FULL")),
        ])
        _ = try await repository.fetchRecruitment()

        await #expect(throws: RecruitmentError.self) { try await repository.apply(motivation: "동기") }
        #expect(log.requests(path: Self.currentPath).count == 2)
        #expect(log.requests(path: Self.applyPath).count == 1)
    }

    @Test func alreadyAppliedErrorCarriesMyApplication() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (409, Self.errorJSON("ALREADY_APPLIED")),
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: "APPROVED", waitingForAssignment: true)),
        ])

        do {
            _ = try await repository.apply(motivation: "동기")
            Issue.record("에러가 나야 한다")
        } catch RecruitmentError.alreadyApplied(let application) {
            #expect(application == RecruitmentApplication(order: 4, appliedAt: Self.appliedAt, isAreaAssigned: false))
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
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: true)),
            Self.myApplicationPath: (404, Self.errorJSON("NO_APPLICATION")),
        ])

        #expect(try await repository.fetchMyApplication() == nil)
    }

    /// 이전 데이터의 PENDING은 서버가 배정 대기를 false로 주지만 배정된 것이 아니다.
    @Test(arguments: [
        ("PENDING", false, false),
        ("APPROVED", true, false),
        ("APPROVED", false, true),
    ])
    func myApplicationAreaAssignment(status: String, waitingForAssignment: Bool, isAreaAssigned: Bool) async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: true)),
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: status, waitingForAssignment: waitingForAssignment)),
        ])

        #expect(try await repository.fetchMyApplication()?.isAreaAssigned == isAreaAssigned)
    }

    @Test func rejectedApplicationIsNil() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: true)),
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: "REJECTED")),
        ])

        #expect(try await repository.fetchMyApplication() == nil)
    }

    /// 신청 시각은 서버 값이라 읽을 수 없으면 지어내지 않고 실패로 둔다.
    @Test func unreadableAppliedAtIsDecodingError() async throws {
        let json = Data(#"{"status":"APPROVED","order":4,"appliedAt":"어제","waitingForAssignment":true}"#.utf8)
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: true)),
            Self.myApplicationPath: (200, json),
        ])

        await #expect(throws: APIError.decoding) { try await repository.fetchMyApplication() }
    }

    /// 활동 시간은 공고 값(`LocalTime` `"07:00:00"`)을 쓴다. 읽을 수 없으면 서버 기본값(07:20~08:10)으로 보여 준다.
    @Test(arguments: [
        (#"{"start":"07:00:00","end":"07:50:00"}"#, 420, 470),
        (#"{"start":"07:00","end":"07:50"}"#, 420, 470),
        (#"{"start":"아침","end":"07:50:00"}"#, 440, 490),
        (#"{"start":"08:10:00","end":"07:20:00"}"#, 440, 490),
    ] as [(String, Int, Int)])
    func activityTimeComesFromRecruitment(activityTime: String, startMinute: Int, endMinute: Int) async throws {
        let repository = makeRepository(responses: [Self.currentPath: (200, Self.currentJSON(activityTime: activityTime))])

        let detail = try #require(try await repository.fetchRecruitment())

        #expect(detail.activityWindow == CleaningWindow(startMinute: startMinute, endMinute: endMinute))
    }
}

extension RecruitmentRepositoryImplTests {
    /// 반려 등으로 보여 줄 신청이 없는데 이미 신청했으면 다시 신청할 수 없으니 마감으로 보여 준다.
    @Test func appliedWithoutShowableApplicationIsEnded() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: true)),
            Self.myApplicationPath: (200, Self.myApplicationJSON(status: "REJECTED")),
        ])

        let detail = try #require(try await repository.fetchRecruitment())

        #expect(detail.myApplication == nil)
        #expect(detail.status == .ended)
    }

    /// 409 이미 신청인데 보여 줄 신청이 없으면 마감으로 알려 같은 실패를 되풀이하지 않는다.
    @Test(arguments: [
        (200, Data(#"{"status":"REJECTED","order":7,"appliedAt":"2026-09-01T12:34:00","waitingForAssignment":false}"#.utf8)),
        (404, Data(#"{"code":"NO_APPLICATION","message":"메시지"}"#.utf8)),
    ])
    func alreadyAppliedWithoutApplicationIsFull(statusCode: Int, json: Data) async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Self.currentPath: (200, Self.currentJSON()),
            Self.applyPath: (409, Self.errorJSON("ALREADY_APPLIED")),
            Self.myApplicationPath: (statusCode, json),
        ])

        do {
            _ = try await repository.apply(motivation: "동기")
            Issue.record("에러가 나야 한다")
        } catch RecruitmentError.full {
        }
        #expect(log.requests(path: Self.applyPath).count == 1)
    }

    /// `applications/me`는 지난 모집의 신청일 수 있어 현재 공고에 신청하지 않았으면 쓰지 않는다.
    @Test func pastApplicationIsNotMyApplication() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            Self.currentPath: (200, Self.currentJSON(alreadyApplied: false)),
            Self.myApplicationPath: (200, Self.myApplicationJSON()),
        ])

        #expect(try await repository.fetchMyApplication() == nil)
        #expect(try await repository.fetchRecruitment()?.myApplication == nil)
        #expect(log.requests(path: Self.myApplicationPath).isEmpty)
    }

    @Test func noCurrentRecruitmentHasNoMyApplication() async throws {
        let repository = makeRepository(responses: [
            Self.currentPath: (404, Self.errorJSON("NO_ACTIVE_RECRUITMENT")),
            Self.myApplicationPath: (200, Self.myApplicationJSON()),
        ])

        #expect(try await repository.fetchMyApplication() == nil)
    }

    /// 학기는 `"2026-2"`(연도-학기)를 먼저, 아니면 끝 숫자(1·2)를 읽는다. 그래도 읽을 수 없으면 학기 없이 보여 준다.
    @Test(arguments: [("2026-1", 1), ("2026-2", 2), ("1", 1), ("2학기", 2), ("2026-3", nil), ("여름", nil)] as [(String, Int?)])
    func semesterParsesYearDashSemester(semester: String, expected: Int?) async throws {
        let repository = makeRepository(responses: [Self.currentPath: (200, Self.currentJSON(semester: semester))])

        #expect(try await repository.fetchRecruitment()?.recruitment.semester == expected)
    }

    /// 들고 있던 공고가 그새 바뀌었으면(새 모집) 사용자가 보지 않은 공고에 신청되지 않게 다시 보내지 않고,
    /// 화면이 공고를 새로 불러오도록 기간 아님으로 알린다.
    @Test(arguments: [(400, "OUT_OF_PERIOD"), (409, "RECRUITMENT_FULL"), (409, "ALREADY_APPLIED"), (404, "RECRUITMENT_NOT_FOUND")])
    func changedRecruitmentIsNotResent(statusCode: Int, code: String) async throws {
        let log = RequestLog()
        let currentCalls = OSAllocatedUnfairLock(initialState: 0)
        let first = Self.currentJSON(id: 7)
        let second = Self.currentJSON(id: 8)
        let error = Self.errorJSON(code)
        let applied = Data(#"{"applicationId":12,"status":"APPROVED","order":2,"studentNumber":"2310","name":"최민준","appliedAt":"2026-09-01T12:34:00"}"#.utf8)
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { request in
                log.append(request)
                switch request.url?.path() {
                case Self.currentPath:
                    let call = currentCalls.withLock { $0 += 1; return $0 }
                    return (200, call == 1 ? first : second)
                case Self.applyPath: return (statusCode, error)
                case "/api/v1/recruitments/8/applications": return (201, applied)
                default: return (404, Data())
                }
            }
        )
        let repository = RecruitmentRepositoryImpl(
            apiClient: APIClient(
                httpClient: httpClient,
                authSession: AuthSession(tokenStore: InMemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), httpClient: httpClient)
            ),
            currentUserRepository: MockCurrentUserRepository()
        )
        _ = try await repository.fetchRecruitment()

        do {
            _ = try await repository.apply(motivation: "동기")
            Issue.record("에러가 나야 한다")
        } catch RecruitmentError.notInPeriod {
        }
        #expect(log.requests.compactMap { $0.url?.path() } == [Self.currentPath, Self.applyPath, Self.currentPath])
    }

    /// 다시 조회했더니 공고가 없어졌어도 다시 보내지 않고 기간 아님으로 알린다.
    @Test func removedRecruitmentIsNotInPeriod() async throws {
        let currentCalls = OSAllocatedUnfairLock(initialState: 0)
        let current = Self.currentJSON()
        let noRecruitment = Self.errorJSON("NO_ACTIVE_RECRUITMENT")
        let full = Self.errorJSON("RECRUITMENT_FULL")
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { request in
                switch request.url?.path() {
                case Self.currentPath:
                    let call = currentCalls.withLock { $0 += 1; return $0 }
                    return call == 1 ? (200, current) : (404, noRecruitment)
                default: return (409, full)
                }
            }
        )
        let repository = RecruitmentRepositoryImpl(
            apiClient: APIClient(
                httpClient: httpClient,
                authSession: AuthSession(tokenStore: InMemoryTokenStore(AuthTokens(accessToken: "a", refreshToken: "r")), httpClient: httpClient)
            ),
            currentUserRepository: MockCurrentUserRepository()
        )
        _ = try await repository.fetchRecruitment()

        do {
            _ = try await repository.apply(motivation: "동기")
            Issue.record("에러가 나야 한다")
        } catch RecruitmentError.notInPeriod {
        } catch {
            Issue.record("기간 아님이어야 한다: \(error)")
        }
    }

    /// 학번·이름은 내 정보(`GET /users/me`)에서 쓴다. 학번을 모르면 nil이라 화면이 그 줄을 숨긴다.
    @Test(arguments: ["2310", nil] as [String?])
    func applicantComesFromCurrentUser(studentNumber: String?) async throws {
        let user = CurrentUser(id: "5", name: "김서연", studentNumber: studentNumber, grade: 2, classNumber: 3)
        let repository = makeRepository(currentUser: user, responses: [:])

        #expect(try await repository.fetchApplicant() == Applicant(studentNumber: studentNumber, name: "김서연"))
    }

    /// 학번·이름을 받지 못해도 공고 화면은 뜬다. 신청자 줄은 비어 화면이 숨긴다.
    @Test func applicantFailureStillLoadsRecruitment() async throws {
        let repository = makeRepository(currentUser: nil, responses: [Self.currentPath: (200, Self.currentJSON())])

        let result = try await FetchRecruitmentUseCase(recruitmentRepository: repository).execute()

        #expect(result.detail != nil)
        #expect(result.applicant == Applicant(studentNumber: nil, name: nil))
    }
}

/// 서버 날짜 파싱 자체는 `ServerDateTests`(#57)가 본다. 여기서는 이 저장소들이 더한 것만 본다.
struct ServerDateDecodingTests {
    @Test func unreadableDateTimeIsDecodingError() {
        #expect(throws: APIError.decoding) { try ServerDate.requiredDateTime("어제") }
    }

    /// 어림한 학기를 단정하지 않는다. 읽을 수 없으면 nil.
    @Test func semesterParsing() {
        #expect(ServerSemester.number(" 2026-2 ") == 2)
        #expect(ServerSemester.number("2026년 1학기") == 1)
        #expect(ServerSemester.number("3") == nil)
        #expect(ServerSemester.number("2026") == nil)
        #expect(ServerSemester.number("") == nil)
    }

    @Test func parsesCleanTime() {
        #expect(ServerDate.minuteRange("07:20~08:10")! == (440, 490))
        #expect(ServerDate.minuteRange("8:00 - 8:10")! == (480, 490))
        #expect(ServerDate.minuteRange("아침") == nil)
    }
}
