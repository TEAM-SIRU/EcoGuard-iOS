import Foundation
import os

/// 토큰 보관과 재발급. 여러 요청이 동시에 401을 받아도 리프레시 요청은 한 번만 보낸다.
///
/// actor는 재진입 가능해서 `await` 중에 다른 호출이 들어온다. 그래서 진행 중인 재발급을 `refreshTask`로 들고 있고,
/// 뒤에 온 호출은 새로 요청하지 않고 그 Task를 기다린다.
actor AuthSession {
    private let tokenStore: TokenStore
    private let httpClient: HTTPClient
    private let logger = Logger(subsystem: "EcoGuard", category: "AuthSession")
    /// 키체인을 매 요청 읽지 않도록 한 번 읽은 값을 들고 있는다. 바깥 nil = 아직 안 읽음.
    private var cachedTokens: AuthTokens??
    private var refreshTask: Task<AuthTokens, Error>?
    /// 로그인·로그아웃마다 올린다. 그 전에 시작한 재발급 결과는 저장하지 않는다(로그아웃 뒤 토큰이 되살아나지 않게).
    private var generation = 0

    /// 리프레시 토큰이 무효라 세션을 지웠을 때 알린다.
    nonisolated let expirations = SessionExpirationBroadcaster()

    init(tokenStore: TokenStore, httpClient: HTTPClient) {
        self.tokenStore = tokenStore
        self.httpClient = httpClient
    }

    /// 앱 시작 시 로그인 유지 판단용. 키체인을 바로 읽는다.
    nonisolated func hasStoredSession() -> Bool {
        tokenStore.load() != nil
    }

    func accessToken() -> String? {
        tokens?.accessToken
    }

    func save(_ newTokens: AuthTokens) {
        generation += 1
        store(newTokens)
    }

    func clear() {
        generation += 1
        refreshTask = nil
        tokenStore.clear()
        cachedTokens = .some(nil)
    }

    /// `failedAccessToken`으로 401을 받은 요청이 다시 보낼 토큰.
    /// 그새 다른 요청이 재발급을 마쳤으면 그 토큰을, 재발급 중이면 그 결과를 기다려 돌려준다.
    func validAccessToken(replacing failedAccessToken: String?) async throws -> String {
        if let current = tokens?.accessToken, current != failedAccessToken {
            return current
        }
        if let refreshTask {
            return try await refreshTask.value.accessToken
        }
        guard let refreshToken = tokens?.refreshToken else {
            // 이미 비어 있다(로그아웃했거나 앞선 만료로 지웠다). 만료 이벤트를 또 보내지 않는다.
            throw APIError.sessionExpired
        }
        let task = Task { try await requestRefresh(refreshToken: refreshToken, generation: generation) }
        refreshTask = task
        defer {
            // 그새 로그아웃으로 비웠거나 다른 재발급이 들어섰으면 건드리지 않는다.
            if refreshTask == task { refreshTask = nil }
        }
        return try await task.value.accessToken
    }

    private var tokens: AuthTokens? {
        if let cachedTokens { return cachedTokens }
        let loaded = tokenStore.load()
        cachedTokens = .some(loaded)
        return loaded
    }

    private func requestRefresh(refreshToken: String, generation startedGeneration: Int) async throws -> AuthTokens {
        let (data, response) = try await httpClient.data(for: .refresh(refreshToken: refreshToken), accessToken: nil)
        if response.statusCode == 401 {
            if generation == startedGeneration { expire() }
            throw APIError.sessionExpired
        }
        let body = try HTTPClient.validate(data, response)
        guard let newTokens = try? JSONDecoder().decode(TokenResponseDTO.self, from: body).tokens else {
            throw APIError.decoding
        }
        guard generation == startedGeneration else { throw APIError.sessionExpired }
        // 리프레시 토큰도 회전하므로 둘 다 바꾼다.
        store(newTokens)
        return newTokens
    }

    private func store(_ newTokens: AuthTokens) {
        cachedTokens = .some(newTokens)
        do {
            try tokenStore.save(newTokens)
        } catch {
            // 메모리 값으로 이번 실행은 계속 쓴다. 다음 실행은 키체인의 이전 토큰으로 재발급을 시도한다.
            logger.error("토큰 저장 실패: \(String(describing: error), privacy: .public)")
        }
    }

    private func expire() {
        clear()
        expirations.send()
    }
}

/// 세션 만료 이벤트를 구독자마다 따로 받는 스트림으로 나눠 준다.
nonisolated final class SessionExpirationBroadcaster: Sendable {
    private let continuations = OSAllocatedUnfairLock<[UUID: AsyncStream<Void>.Continuation]>(initialState: [:])

    func stream() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuations.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { _ = $0.removeValue(forKey: id) }
        }
        return stream
    }

    func send() {
        for continuation in continuations.withLock({ Array($0.values) }) {
            continuation.yield()
        }
    }
}
