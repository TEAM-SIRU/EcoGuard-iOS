import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct NoticeRepositoryImplTests {
    private func makeRepository(log: RequestLog = RequestLog(), responses: [String: (Int, Data)]) -> NoticeRepositoryImpl {
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
        return NoticeRepositoryImpl(apiClient: APIClient(httpClient: httpClient, authSession: authSession))
    }

    private static func kst(day: Int, hour: Int) -> Date {
        MockRecruitmentRepository.Fixture.calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    @Test func fetchNoticesMapsList() async throws {
        let log = RequestLog()
        let json = Data("""
        [{"noticeId":2,"title":"9월 활동 안내","preview":"매일 08:00에 청소해요","isRead":false,"createdAt":"2026-09-02T09:00:00.123"},
         {"noticeId":1,"title":"모집 안내","preview":"2학기 모집","isRead":true,"createdAt":"2026-09-01T08:00:00"}]
        """.utf8)
        let repository = makeRepository(log: log, responses: ["/api/v1/notices": (200, json)])

        let notices = try await repository.fetchNotices()

        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.bearerToken == "access")
        #expect(notices == [
            Notice(id: "2", title: "9월 활동 안내", body: "", preview: "매일 08:00에 청소해요", publishedAt: Self.kst(day: 2, hour: 9), isRead: false),
            Notice(id: "1", title: "모집 안내", body: "", preview: "2학기 모집", publishedAt: Self.kst(day: 1, hour: 8), isRead: true),
        ])
        #expect(notices.map(\.isNew) == [true, false])
    }

    @Test func emptyListIsEmpty() async throws {
        let repository = makeRepository(responses: ["/api/v1/notices": (200, Data("[]".utf8))])

        #expect(try await repository.fetchNotices().isEmpty)
    }

    /// 상세를 받으면 서버가 읽음으로 기록하므로 읽은 공지다. 미리보기는 서버처럼 공백을 정리한다.
    @Test func fetchNoticeMapsDetail() async throws {
        let json = Data(#"{"noticeId":2,"title":"안내","content":"**08:00**에\n  청소해요","createdAt":"2026-09-02T09:00:00","previousNoticeId":1,"nextNoticeId":null}"#.utf8)
        let repository = makeRepository(responses: ["/api/v1/notices/2": (200, json)])

        let notice = try await repository.fetchNotice(id: "2")

        #expect(notice == Notice(
            id: "2",
            title: "안내",
            body: "**08:00**에\n  청소해요",
            preview: "**08:00**에 청소해요",
            publishedAt: Self.kst(day: 2, hour: 9),
            isRead: true
        ))
    }

    @Test func missingNoticeIsNil() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log, responses: [
            "/api/v1/notices/3": (404, Data(#"{"code":"NOTICE_NOT_FOUND","message":"존재하지 않는 공지입니다."}"#.utf8)),
        ])

        #expect(try await repository.fetchNotice(id: "3") == nil)
        // 숫자가 아닌 ID(Mock 공지 등)는 서버에 묻지 않는다.
        #expect(try await repository.fetchNotice(id: "notice-2026-09") == nil)
        #expect(log.requests.count == 1)
    }

    @Test func malformedDateIsDecodingError() async throws {
        let json = Data(#"[{"noticeId":1,"title":"안내","createdAt":"어제"}]"#.utf8)
        let repository = makeRepository(responses: ["/api/v1/notices": (200, json)])

        await #expect(throws: APIError.decoding) { try await repository.fetchNotices() }
    }
}
