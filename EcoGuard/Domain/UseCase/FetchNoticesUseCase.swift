struct FetchNoticesUseCase {
    private let noticeRepository: NoticeRepository

    init(noticeRepository: NoticeRepository) {
        self.noticeRepository = noticeRepository
    }

    func execute() async throws -> [Notice] {
        try await noticeRepository.fetchNotices()
    }
}
