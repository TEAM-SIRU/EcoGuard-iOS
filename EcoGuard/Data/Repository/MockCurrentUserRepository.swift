/// 서버 연동 전까지 쓰는 Mock. 마이페이지 Mock(Figma `12 전체`)과 같은 사용자.
final class MockCurrentUserRepository: CurrentUserRepository {
    static let user = CurrentUser(id: "1", name: "최민준", studentNumber: "2310", grade: 2, classNumber: 3)

    struct FetchFailedError: Error {}
    struct WithdrawFailedError: Error {}

    private var user: CurrentUser?
    private(set) var withdrawCallCount = 0
    private let withdrawFails: Bool

    /// `user`가 nil이면 내 정보를 받아 오지 못한 것처럼 에러를 던진다. `withdrawFails`면 탈퇴 요청이 실패한다.
    init(user: CurrentUser? = MockCurrentUserRepository.user, withdrawFails: Bool = false) {
        self.user = user
        self.withdrawFails = withdrawFails
    }

    func fetchCurrentUser() async throws -> CurrentUser {
        guard let user else { throw FetchFailedError() }
        return user
    }

    func withdraw() async throws {
        withdrawCallCount += 1
        if withdrawFails { throw WithdrawFailedError() }
        user = nil
    }
}
