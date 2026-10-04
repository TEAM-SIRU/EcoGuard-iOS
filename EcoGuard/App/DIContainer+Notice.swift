import Foundation

extension DIContainer {
    /// 공지 화면.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다.
    func makeNoticeViewModel(
        repository: NoticeRepository = MockNoticeRepository()
    ) -> NoticeViewModel {
        NoticeViewModel(fetchNoticesUseCase: FetchNoticesUseCase(noticeRepository: repository))
    }
}
