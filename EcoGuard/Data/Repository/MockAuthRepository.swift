/// 실제 dataGSM OAuth 연동 전까지 쓰는 Mock. 지연 후 정해진 결과를 돌려준다.
final class MockAuthRepository: AuthRepository {
    enum Outcome {
        case student
        case teacher
        case failure
    }

    struct LoginFailedError: Error {}

    private let outcome: Outcome
    private let delay: Duration
    private(set) var loginCallCount = 0
    private(set) var logoutCallCount = 0

    init(outcome: Outcome = .student, delay: Duration = .seconds(1)) {
        self.outcome = outcome
        self.delay = delay
    }

    func login() async throws -> UserRole {
        loginCallCount += 1
        try await Task.sleep(for: delay)
        switch outcome {
        case .student:
            return .student
        case .teacher:
            return .teacher
        case .failure:
            throw LoginFailedError()
        }
    }

    func logout() async {
        logoutCallCount += 1
    }
}
