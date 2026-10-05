import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct AppealRepositoryImplTests {
    private nonisolated static let mePath = "/api/v1/appeals/me"
    private nonisolated static let createPath = "/api/v1/verifications/7/appeals"

    private static func makeRepository(handler: @escaping StubURLProtocol.Handler) -> AppealRepositoryImpl {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession(handler: handler)
        )
        let store = InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        return AppealRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient))
        )
    }

    private nonisolated static func appealJSON(
        id: Int,
        verificationID: Int = 7,
        round: Int = 1,
        status: String,
        reply: String? = nil,
        createdAt: String = "2026-09-29T12:20:05.123456"
    ) -> String {
        let replyJSON = reply.map { "\"\($0)\"" } ?? "null"
        return #"{"appealId":\#(id),"verificationId":\#(verificationID),"round":\#(round),"areaName":"본관","verificationDate":"2026-09-22","content":"c","status":"\#(status)","reply":\#(replyJSON),"createdAt":"\#(createdAt)"}"#
    }

    private nonisolated static func list(_ items: String...) -> Data {
        Data("[\(items.joined(separator: ","))]".utf8)
    }

    private static func kst(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private static let draft = AppealDraft(requestID: "req-1", verificationID: "7", message: "다시 봐 주세요", photos: [])

    @Test func fetchAppealsMapsStatusesAndDates() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (200, Self.list(
                Self.appealJSON(id: 3, round: 2, status: "PENDING"),
                Self.appealJSON(id: 2, status: "REJECTED", reply: "표지판이 보이지 않아요", createdAt: "2026-09-22T13:02:00"),
                Self.appealJSON(id: 1, verificationID: 6, status: "APPROVED", reply: "확인했어요")
            ))
        }

        let appeals = try await repository.fetchAppeals()

        #expect(log.requests(path: Self.mePath).map(\.httpMethod) == ["GET"])
        #expect(appeals.map(\.id) == ["3", "2", "1"])
        #expect(appeals.map(\.status) == [.reviewing, .rejected, .approved])
        #expect(appeals.map(\.earnedMinutes) == [0, 0, 10])
        #expect(appeals[0] == Appeal(
            id: "3",
            verificationID: "7",
            verifiedAt: Self.kst(9, 22),
            round: 2,
            submittedAt: Self.kst(9, 29, 12, 20, 5),
            status: .reviewing,
            earnedMinutes: 0,
            teacherReply: nil,
            photoURL: nil
        ))
        #expect(appeals[1].submittedAt == Self.kst(9, 22, 13, 2))
        #expect(appeals[1].teacherReply == .init(title: "표지판이 보이지 않아요", message: nil))
        // 승인 답변은 반려 사유가 아니라 쓰지 않는다.
        #expect(appeals[2].teacherReply == nil)
    }

    @Test func submitPostsContentThenReturnsAppealFromHistory() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.createPath {
                return (201, Data(#"{"appealId":9,"status":"PENDING","round":2}"#.utf8))
            }
            return (200, Self.list(Self.appealJSON(id: 9, round: 2, status: "PENDING"), Self.appealJSON(id: 2, status: "REJECTED")))
        }

        let appeal = try await repository.submitAppeal(Self.draft)

        #expect(appeal.id == "9")
        #expect(appeal.round == 2)
        #expect(appeal.status == .reviewing)
        let create = try #require(log.requests(path: Self.createPath).first)
        #expect(create.httpMethod == "POST")
        #expect(create.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode([String: String].self, from: try #require(create.bodyData))
        #expect(body == ["content": "다시 봐 주세요"])
    }

    @Test(arguments: [("APPEAL_ALREADY_PENDING", 409), ("APPEAL_NOT_ALLOWED", 409), ("VERIFICATION_NOT_FOUND", 404)])
    func submitServerErrorsPassThrough(code: String, statusCode: Int) async throws {
        let repository = Self.makeRepository { _ in
            (statusCode, Data(#"{"code":"\#(code)","message":"m"}"#.utf8))
        }

        await #expect(throws: APIError.server(statusCode: statusCode, code: code)) {
            try await repository.submitAppeal(Self.draft)
        }
    }

    /// 접수됐지만 응답을 받지 못한 제출 → 같은 `requestID` 조회가 그 인증의 검토 중 이의신청을 찾는다.
    @Test func fetchByRequestIDFindsPendingAppealAfterLostResponse() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            if request.url?.path() == Self.createPath { throw URLError(.networkConnectionLost) }
            return (200, Self.list(
                Self.appealJSON(id: 5, verificationID: 6, status: "PENDING"),
                Self.appealJSON(id: 4, status: "PENDING"),
                Self.appealJSON(id: 2, status: "REJECTED")
            ))
        }

        await #expect(throws: URLError.self) {
            try await repository.submitAppeal(Self.draft)
        }
        let found = try await repository.fetchAppeal(requestID: Self.draft.requestID)

        #expect(found?.id == "4")
    }

    @Test func fetchByRequestIDIsNilWhenNotReceived() async throws {
        let repository = Self.makeRepository { request in
            if request.url?.path() == Self.createPath { throw URLError(.networkConnectionLost) }
            return (200, Self.list(Self.appealJSON(id: 2, status: "REJECTED")))
        }

        await #expect(throws: URLError.self) {
            try await repository.submitAppeal(Self.draft)
        }

        #expect(try await repository.fetchAppeal(requestID: Self.draft.requestID) == nil)
    }

    /// 이 저장소로 보낸 적 없는 `requestID`는 서버에 묻지 않는다.
    @Test func fetchByUnknownRequestIDSkipsServer() async throws {
        let log = RequestLog()
        let repository = Self.makeRepository { request in
            log.append(request)
            return (200, Self.list())
        }

        #expect(try await repository.fetchAppeal(requestID: "unknown") == nil)
        #expect(log.requests.isEmpty)
    }

    @Test func malformedCreatedAtIsDecodingError() async throws {
        let repository = Self.makeRepository { _ in
            (200, Self.list(Self.appealJSON(id: 1, status: "PENDING", createdAt: "2026-09-29 12:20")))
        }

        await #expect(throws: APIError.decoding) {
            try await repository.fetchAppeals()
        }
    }
}
