/// 회원 탈퇴. 마이페이지 `회원탈퇴`에서 부른다.
struct WithdrawUseCase {
    private let currentUserRepository: CurrentUserRepository

    init(currentUserRepository: CurrentUserRepository) {
        self.currentUserRepository = currentUserRepository
    }

    func execute() async throws {
        try await currentUserRepository.withdraw()
    }
}
