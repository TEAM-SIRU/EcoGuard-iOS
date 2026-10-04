protocol AppealRepository {
    /// 내가 보낸 이의신청 전체. 최근에 보낸 것부터.
    func fetchAppeals() async throws -> [Appeal]
    /// `requestID`로 이미 접수된 이의신청을 찾는다. 접수되지 않았으면 nil.
    func fetchAppeal(requestID: String) async throws -> Appeal?
    /// 이의신청을 보낸다. 같은 `requestID`로 다시 보내도 한 건으로 접수돼야 한다.
    func submitAppeal(_ draft: AppealDraft) async throws -> Appeal
}
