import Foundation

extension DIContainer {
    /// 인증 결과·상세 화면.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다. 다른 화면 작업과 충돌을 피하려고 따로 둔다.
    func makeVerificationResultViewModel(
        resultID: String,
        repository: VerificationResultRepository = MockVerificationResultRepository()
    ) -> VerificationResultViewModel {
        VerificationResultViewModel(
            resultID: resultID,
            fetchResultUseCase: FetchVerificationResultUseCase(verificationResultRepository: repository)
        )
    }
}
