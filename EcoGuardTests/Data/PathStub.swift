import Foundation
import os
@testable import EcoGuard

/// 경로마다 정해진 응답을 주는 스텁 클라이언트. 등록하지 않은 경로는 404(바디 없음)다.
enum PathStub {
    static let baseURL = URL(string: "https://api.example.com")!
    static let tokens = AuthTokens(accessToken: "access", refreshToken: "refresh")

    /// `responses`: 경로 → (상태 코드, JSON 문자열).
    static func makeClient(
        log: RequestLog,
        responses: [String: (Int, String)],
        userStore: SessionUserStore = InMemorySessionUserStore()
    ) -> APIClient {
        let session = StubURLProtocol.makeSession { request in
            log.append(request)
            guard let (statusCode, body) = responses[request.url?.path() ?? ""] else { return (404, Data()) }
            return (statusCode, Data(body.utf8))
        }
        let httpClient = HTTPClient(baseURL: baseURL, session: session)
        return APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: InMemoryTokenStore(tokens), httpClient: httpClient, userStore: userStore))
    }

    static func error(_ code: String) -> String {
        #"{"code":"\#(code)","message":"메시지"}"#
    }

    /// 학교 시간대(KST) 시각.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        HomeMapper.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }
}

/// 테스트용 인메모리 사용자 요약 저장소. 기본 저장소(UserDefaults.standard)를 테스트끼리 공유하지 않게 한다.
final class InMemorySessionUserStore: SessionUserStore {
    private let user: OSAllocatedUnfairLock<SessionUser?>

    init(_ user: SessionUser? = nil) {
        self.user = OSAllocatedUnfairLock(initialState: user)
    }

    func load() -> SessionUser? { user.withLock { $0 } }
    func save(_ newUser: SessionUser) { user.withLock { $0 = newUser } }
    func clear() { user.withLock { $0 = nil } }
}
