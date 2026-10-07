import Foundation

extension DIContainer {
    /// 청소 구역 화면. `repository`를 주지 않으면 서버 주소에 따라 실제 구현이나 Mock을 쓴다.
    func makeCleaningAreaViewModel(
        repository: CleaningAreaRepository? = nil
    ) -> CleaningAreaViewModel {
        let repository = repository ?? apiClient.map { CleaningAreaRepositoryImpl(apiClient: $0, currentUserRepository: currentUserRepository) } ?? MockCleaningAreaRepository(store: mockStore)
        return CleaningAreaViewModel(fetchCleaningAreaUseCase: FetchCleaningAreaUseCase(cleaningAreaRepository: repository))
    }
}
