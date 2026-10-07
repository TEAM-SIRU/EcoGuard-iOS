import Foundation

extension DIContainer {
    /// 인증 결과·상세 화면.
    func makeVerificationResultViewModel(
        resultID: String,
        repository: VerificationResultRepository? = nil
    ) -> VerificationResultViewModel {
        let repository = repository ?? apiClient.map { VerificationResultRepositoryImpl(apiClient: $0) }
            ?? MockVerificationResultRepository.matchingOtherMocks(
                scenario: Self.mockScenario("ECO_MOCK_VERIFICATION_RESULT_SCENARIO") ?? .approved,
                store: mockStore
            )
        return VerificationResultViewModel(
            resultID: resultID,
            fetchResultUseCase: FetchVerificationResultUseCase(verificationResultRepository: repository)
        )
    }
}
