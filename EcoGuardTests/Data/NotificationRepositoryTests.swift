import Foundation
import Testing
@testable import EcoGuard

@MainActor
struct NotificationRepositoryTests {
    private func makeRepository(log: RequestLog) -> NotificationRepository {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { request in
                log.append(request)
                switch (request.httpMethod, request.url?.path()) {
                case ("GET", "/api/v1/notifications"):
                    return (200, Data("""
                    {"unreadCount":1,"notifications":[{"id":42,"type":"NOTICE_CREATED","title":"공지","body":"새 공지","refId":7,"isRead":false,"createdAt":"2026-11-25T09:00:00"}]}
                    """.utf8))
                case ("PATCH", "/api/v1/notifications/42/read"), ("PATCH", "/api/v1/notifications/read-all"):
                    return (200, Data())
                default:
                    return (404, Data())
                }
            }
        )
        let authSession = AuthSession(
            tokenStore: InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh")),
            httpClient: httpClient
        )
        return NotificationRepository(apiClient: APIClient(httpClient: httpClient, authSession: authSession))
    }

    @Test func fetchInboxDecodesListAndUnreadCount() async throws {
        let log = RequestLog()
        let inbox = try await makeRepository(log: log).fetchInbox()
        let notification = try #require(inbox.notifications.first)
        let request = try #require(log.requests.first)

        #expect(inbox.unreadCount == 1)
        #expect(notification.id == 42)
        #expect(notification.body == "새 공지")
        #expect(!notification.isRead)
        #expect(request.httpMethod == "GET")
        #expect(request.bearerToken == "access")
    }

    @Test func sendsAuthenticatedReadRequestsWithEmptyResponses() async throws {
        let log = RequestLog()
        let repository = makeRepository(log: log)
        try await repository.markRead(id: 42)
        try await repository.markAllRead()

        #expect(log.requests.map { $0.url?.path() } == [
            "/api/v1/notifications/42/read",
            "/api/v1/notifications/read-all",
        ])
        #expect(log.requests.allSatisfy { $0.httpMethod == "PATCH" && $0.bearerToken == "access" })
    }
}
