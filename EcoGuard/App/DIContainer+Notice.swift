import Foundation

extension DIContainer {
    /// 공지 화면. `repository`를 주지 않으면 서버 주소에 따라 실제 구현이나 Mock을 쓴다.
    func makeNoticeViewModel(
        repository: NoticeRepository? = nil
    ) -> NoticeViewModel {
        let repository = repository ?? apiClient.map { NoticeRepositoryImpl(apiClient: $0) } ?? MockNoticeRepository()
        return NoticeViewModel(fetchNoticesUseCase: FetchNoticesUseCase(noticeRepository: repository))
    }
}
