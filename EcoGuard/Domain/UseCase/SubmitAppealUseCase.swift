struct SubmitAppealUseCase {
    private let appealRepository: AppealRepository

    init(appealRepository: AppealRepository) {
        self.appealRepository = appealRepository
    }

    /// - Parameter checksPreviousSubmission: 앞선 제출이 실패·취소됐으면 true. 서버에 닿았을 수 있어
    ///   같은 `requestID`로 먼저 조회하고, 이미 접수됐으면 다시 보내지 않고 그 결과를 돌려준다.
    func execute(_ draft: AppealDraft, checksPreviousSubmission: Bool) async throws -> Appeal {
        if checksPreviousSubmission, let appeal = try await appealRepository.fetchAppeal(requestID: draft.requestID) {
            return appeal
        }
        return try await appealRepository.submitAppeal(draft)
    }
}
