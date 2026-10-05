/// 실제 dataGSM OAuth 연동 전까지 쓰는 Mock. 지연 후 정해진 결과를 차례대로 돌려준다.
final class MockAuthRepository: AuthRepository {
    enum Outcome {
        case student
        case teacher
        case failure
        case cancelled
    }

    struct LoginFailedError: Error {}
    struct LogoutFailedError: Error {}

    private var outcomes: [Outcome]
    private let delay: Duration
    private let logoutFails: Bool
    private(set) var loginCallCount = 0
    private(set) var logoutCallCount = 0

    /// 호출마다 `outcomes`를 앞에서부터 하나씩 쓰고, 마지막 결과는 이후 호출에도 계속 쓴다.
    /// `logoutFails`면 로그아웃이 지연 후 실패한다(서버 요청 실패 흉내).
    init(outcomes: [Outcome], delay: Duration = .seconds(1), logoutFails: Bool = false) {
        precondition(!outcomes.isEmpty, "outcomes는 비어 있을 수 없다")
        self.outcomes = outcomes
        self.delay = delay
        self.logoutFails = logoutFails
    }

    convenience init(outcome: Outcome = .student, delay: Duration = .seconds(1), logoutFails: Bool = false) {
        self.init(outcomes: [outcome], delay: delay, logoutFails: logoutFails)
    }

    func login() async throws -> UserRole {
        loginCallCount += 1
        let outcome = outcomes.count > 1 ? outcomes.removeFirst() : outcomes[0]
        try await Task.sleep(for: delay)
        switch outcome {
        case .student:
            return .student
        case .teacher:
            return .teacher
        case .failure:
            throw LoginFailedError()
        case .cancelled:
            throw AuthError.cancelled
        }
    }

    func logout() async throws {
        logoutCallCount += 1
        try await Task.sleep(for: delay)
        if logoutFails {
            throw LogoutFailedError()
        }
    }

    /// 기존 동작대로 항상 로그인 화면에서 시작한다.
    func hasStoredSession() -> Bool {
        false
    }

    /// Mock은 세션이 만료되지 않는다.
    func sessionExpirations() -> AsyncStream<Void> {
        AsyncStream { _ in }
    }
}
