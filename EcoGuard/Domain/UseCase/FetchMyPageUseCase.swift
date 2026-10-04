struct FetchMyPageUseCase {
    private let myPageRepository: MyPageRepository

    init(myPageRepository: MyPageRepository) {
        self.myPageRepository = myPageRepository
    }

    func execute() async throws -> MyPageSummary {
        try await myPageRepository.fetchMyPage()
    }
}
