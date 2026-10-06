/// 서버 연동 전까지 쓰는 Mock. 마이페이지 Mock(Figma `12 전체`)과 같은 사용자.
final class MockCurrentUserRepository: CurrentUserRepository {
    static let user = CurrentUser(id: "1", name: "최민준")

    private let user: CurrentUser?

    init(user: CurrentUser? = MockCurrentUserRepository.user) {
        self.user = user
    }

    func currentUser() -> CurrentUser? {
        user
    }
}
