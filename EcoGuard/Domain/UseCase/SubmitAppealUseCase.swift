struct SubmitAppealUseCase {
    private let appealRepository: AppealRepository

    init(appealRepository: AppealRepository) {
        self.appealRepository = appealRepository
    }

    /// - Parameter unconfirmedAttempts: 앞서 보냈지만 접수 여부를 모르는(실패·취소된) 내용. 비어 있지 않으면 서버에 닿았을 수 있어
    ///   같은 `requestID`로 먼저 조회하고, 이미 접수됐으면 다시 보내지 않는다.
    ///   그 내용이 모두 지금 `draft`와 같으면 그대로 완료(`submitted`), 하나라도 다르면 고친 내용이 반영되지 않은 것이라 `alreadyReceived`.
    func execute(_ draft: AppealDraft, unconfirmedAttempts: [AppealDraft]) async throws -> AppealSubmissionResult {
        if !unconfirmedAttempts.isEmpty, let appeal = try await appealRepository.fetchAppeal(requestID: draft.requestID) {
            return unconfirmedAttempts.allSatisfy { $0 == draft } ? .submitted(appeal) : .alreadyReceived(appeal)
        }
        return .submitted(try await appealRepository.submitAppeal(draft))
    }
}
