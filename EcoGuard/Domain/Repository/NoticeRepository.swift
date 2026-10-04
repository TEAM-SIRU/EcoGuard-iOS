protocol NoticeRepository {
    /// 공지 목록을 조회한다.
    func fetchNotices() async throws -> [Notice]
}
