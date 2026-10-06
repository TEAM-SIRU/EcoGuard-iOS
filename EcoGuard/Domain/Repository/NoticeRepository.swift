protocol NoticeRepository {
    /// 공지 목록을 조회한다.
    func fetchNotices() async throws -> [Notice]
    /// 공지 상세(본문 포함). 지워졌거나 없는 공지면 nil.
    func fetchNotice(id: Notice.ID) async throws -> Notice?
}
