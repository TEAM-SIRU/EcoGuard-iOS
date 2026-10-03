import Foundation

extension DIContainer {
    /// 청소 구역 화면.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다.
    func makeCleaningAreaViewModel(
        repository: CleaningAreaRepository = MockCleaningAreaRepository()
    ) -> CleaningAreaViewModel {
        CleaningAreaViewModel(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase(cleaningAreaRepository: repository))
    }
}
