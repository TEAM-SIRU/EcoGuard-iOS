/// 서버 활동 기록. 서버 계약: EcoGuard-Server `activity/ActivityController.kt`.
final class ActivityRepositoryImpl: ActivityRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchMonth(year: Int, month: Int) async throws -> ActivityMonth {
        let response: MyActivityResponseDTO = try await apiClient.send(.myActivity(year: year, month: month))
        return try response.toDomain()
    }
}
