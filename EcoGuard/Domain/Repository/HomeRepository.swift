protocol HomeRepository {
    func fetchHome() async throws -> HomeSummary
    /// 메인 공지를 닫는다. 다음 조회부터 같은 공지를 내려주지 않는다.
    func dismissNotice(id: String) async
}
