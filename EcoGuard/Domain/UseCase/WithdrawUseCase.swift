/// 회원 탈퇴. 화면은 디자인 대기라 아직 연결하지 않았다.
struct WithdrawUseCase {
    private let currentUserRepository: CurrentUserRepository

    init(currentUserRepository: CurrentUserRepository) {
        self.currentUserRepository = currentUserRepository
    }

    func execute() async throws {
        try await currentUserRepository.withdraw()
    }
}
