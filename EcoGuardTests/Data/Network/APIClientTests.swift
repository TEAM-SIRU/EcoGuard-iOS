import Foundation
import Testing
@testable import EcoGuard

struct APIClientTests {
    private static let baseURL = URL(string: "https://api.example.com")!
    private static let oldTokens = AuthTokens(accessToken: "access-old", refreshToken: "refresh-old")
    private static let newTokens = AuthTokens(accessToken: "access-new", refreshToken: "refresh-new")
    private static let refreshPath = "/api/v1/auth/refresh"
    private static let logoutPath = "/api/v1/auth/logout"

    private static func tokenJSON(_ tokens: AuthTokens) -> Data {
        Data(#"{"accessToken":"\#(tokens.accessToken)","refreshToken":"\#(tokens.refreshToken)"}"#.utf8)
    }

    private func makeClient(
        store: InMemoryTokenStore,
        handler: @escaping StubURLProtocol.Handler
    ) -> APIClient {
        let httpClient = HTTPClient(baseURL: Self.baseURL, session: StubURLProtocol.makeSession(handler: handler))
        return APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient))
    }

    /// 동시에 401을 받은 요청 N개 → 리프레시는 1번, 각 요청은 새 토큰으로 1번만 다시 보낸다.
    @Test func concurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let requestCount = 5
        let log = RequestLog()
        let gate = CountGate(target: requestCount)
        let store = InMemoryTokenStore(Self.oldTokens)
        let client = makeClient(store: store) { request in
            log.append(request)
            if request.url?.path() == Self.refreshPath {
                // 모든 요청이 401을 받은 뒤에 재발급을 끝내, N개가 모두 같은 재발급을 기다리게 한다.
                await gate.wait()
                return (200, Self.tokenJSON(Self.newTokens))
            }
            if request.bearerToken == Self.newTokens.accessToken {
                return (200, Data())
            }
            await gate.increment()
            return (401, Data())
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<requestCount {
                group.addTask { try await client.send(Endpoint(method: .get, path: "/api/v1/items/\(index)")) }
            }
            try await group.waitForAll()
        }

        #expect(log.requests(path: Self.refreshPath).count == 1)
        for index in 0..<requestCount {
            let tokens = log.requests(path: "/api/v1/items/\(index)").map(\.bearerToken)
            #expect(tokens == [Self.oldTokens.accessToken, Self.newTokens.accessToken])
        }
    }

    /// 재발급한 토큰으로도 401이면 더 재발급하지 않고 에러로 끝난다. 세션은 지우지 않는다.
    @Test func unauthorizedAfterRetryDoesNotLoop() async throws {
        let log = RequestLog()
        let store = InMemoryTokenStore(Self.oldTokens)
        let client = makeClient(store: store) { request in
            log.append(request)
            if request.url?.path() == Self.refreshPath {
                return (200, Self.tokenJSON(Self.newTokens))
            }
            return (401, Data())
        }

        await #expect(throws: APIError.unauthorized) {
            try await client.send(Endpoint(method: .get, path: "/api/v1/items"))
        }
        #expect(log.requests(path: Self.refreshPath).count == 1)
        #expect(log.requests(path: "/api/v1/items").count == 2)
        #expect(store.current == Self.newTokens)
    }

    /// 리프레시가 401이면 토큰을 지우고 세션 만료를 알린다. 기다리던 요청도 모두 같은 에러로 끝난다.
    @Test func refreshUnauthorizedClearsTokensAndExpiresSession() async throws {
        let requestCount = 3
        let log = RequestLog()
        let gate = CountGate(target: requestCount)
        let store = InMemoryTokenStore(Self.oldTokens)
        let client = makeClient(store: store) { request in
            log.append(request)
            if request.url?.path() == Self.refreshPath {
                await gate.wait()
                return (401, Data())
            }
            await gate.increment()
            return (401, Data())
        }
        var expirations = client.authSession.expirations.stream().makeAsyncIterator()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<requestCount {
                group.addTask {
                    await #expect(throws: APIError.sessionExpired) {
                        try await client.send(Endpoint(method: .get, path: "/api/v1/items/\(index)"))
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(store.current == nil)
        #expect(log.requests(path: Self.refreshPath).count == 1)
        #expect(await expirations.next() != nil)
    }

    /// 리프레시는 Authorization 없이 저장된 리프레시 토큰을 보내고, 응답의 두 토큰을 모두 저장한다.
    @Test func refreshReplacesBothTokens() async throws {
        let log = RequestLog()
        let store = InMemoryTokenStore(Self.oldTokens)
        let client = makeClient(store: store) { request in
            log.append(request)
            if request.url?.path() == Self.refreshPath {
                return (200, Self.tokenJSON(Self.newTokens))
            }
            return request.bearerToken == Self.newTokens.accessToken ? (200, Data()) : (401, Data())
        }

        try await client.send(Endpoint(method: .get, path: "/api/v1/items"))

        let refresh = try #require(log.requests(path: Self.refreshPath).first)
        #expect(refresh.httpMethod == "POST")
        #expect(refresh.value(forHTTPHeaderField: "Authorization") == nil)
        let body = try JSONDecoder().decode([String: String].self, from: try #require(refresh.bodyData))
        #expect(body == ["refreshToken": Self.oldTokens.refreshToken])
        #expect(store.current == Self.newTokens)
        #expect(await client.authSession.accessToken() == Self.newTokens.accessToken)
    }

    /// 재발급이 서버 오류·오프라인으로 실패하면 토큰을 지우지 않는다(로그인 화면으로 보내지 않는다).
    @Test func refreshServerErrorKeepsTokens() async throws {
        let store = InMemoryTokenStore(Self.oldTokens)
        let client = makeClient(store: store) { request in
            if request.url?.path() == Self.refreshPath {
                throw URLError(.notConnectedToInternet)
            }
            return (401, Data())
        }

        await #expect(throws: URLError.self) {
            try await client.send(Endpoint(method: .get, path: "/api/v1/items"))
        }
        #expect(store.current == Self.oldTokens)
    }

    /// 에러 바디가 있으면 서버 코드를 담는다.
    @Test func serverErrorCarriesCode() async throws {
        let store = InMemoryTokenStore(Self.oldTokens)
        let client = makeClient(store: store) { _ in
            (409, Data(#"{"code":"ALREADY_APPLIED","message":"이미 신청했습니다."}"#.utf8))
        }

        await #expect(throws: APIError.server(statusCode: 409, code: "ALREADY_APPLIED")) {
            try await client.send(Endpoint(method: .post, path: "/api/v1/applications"))
        }
    }
}

/// `increment`가 `target`번 불릴 때까지 `wait`를 붙잡는다.
actor CountGate {
    private let target: Int
    private var count = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(target: Int) {
        self.target = target
    }

    func increment() {
        count += 1
        guard count >= target else { return }
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    func wait() async {
        guard count < target else { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}
