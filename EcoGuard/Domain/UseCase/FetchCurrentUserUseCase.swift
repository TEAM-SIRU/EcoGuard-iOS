struct FetchCurrentUserUseCase {
    private let currentUserRepository: CurrentUserRepository

    init(currentUserRepository: CurrentUserRepository) {
        self.currentUserRepository = currentUserRepository
    }

    func execute() -> CurrentUser? {
        currentUserRepository.currentUser()
    }
}
