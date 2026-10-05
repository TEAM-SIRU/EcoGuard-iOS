import Foundation
@testable import EcoGuard

/// 경로마다 정해진 응답을 주는 스텁 클라이언트. 등록하지 않은 경로는 404(바디 없음)다.
enum PathStub {
    static let baseURL = URL(string: "https://api.example.com")!
    static let tokens = AuthTokens(accessToken: "access", refreshToken: "refresh")

    /// `responses`: 경로 → (상태 코드, JSON 문자열).
    static func makeClient(log: RequestLog, responses: [String: (Int, String)]) -> APIClient {
        let session = StubURLProtocol.makeSession { request in
            log.append(request)
            guard let (statusCode, body) = responses[request.url?.path() ?? ""] else { return (404, Data()) }
            return (statusCode, Data(body.utf8))
        }
        let httpClient = HTTPClient(baseURL: baseURL, session: session)
        return APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: InMemoryTokenStore(tokens), httpClient: httpClient))
    }

    static func error(_ code: String) -> String {
        #"{"code":"\#(code)","message":"메시지"}"#
    }

    /// 학교 시간대(KST) 시각.
    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        ServerDate.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }
}
