/// 서버 청소 구역. 서버에는 내 구역 정보만 있고 학교 도면(층·칸)이 없어 도면은 앱이 가진 값을 쓴다.
final class CleaningAreaRepositoryImpl: CleaningAreaRepository {
    private let apiClient: APIClient
    private let floors: [FloorPlan]
    private let currentUserRepository: CurrentUserRepository

    // TODO: 서버가 도면을 내려주면 Mock 도면을 뺀다(서버 요청 목록).
    init(
        apiClient: APIClient,
        currentUserRepository: CurrentUserRepository,
        floors: [FloorPlan] = MockCleaningAreaRepository.Fixture.floors
    ) {
        self.apiClient = apiClient
        self.currentUserRepository = currentUserRepository
        self.floors = floors
    }

    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        do {
            let response: MyAssignmentResponseDTO = try await apiClient.send(.myAssignment)
            // 구성원 중 내 정보의 사용자 ID가 나다. 받아 오지 못하면 나를 따로 표시하지 않는다(구역은 보여 준다).
            let myUserID = try? await currentUserRepository.fetchCurrentUser().id
            return response.toDomain(floors: floors, myUserID: myUserID)
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_ASSIGNMENT") {
            return .unassigned
        }
    }
}
