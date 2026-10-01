struct DismissNoticeUseCase {
    private let homeRepository: HomeRepository

    init(homeRepository: HomeRepository) {
        self.homeRepository = homeRepository
    }

    func execute(noticeID: String) async {
        await homeRepository.dismissNotice(id: noticeID)
    }
}
