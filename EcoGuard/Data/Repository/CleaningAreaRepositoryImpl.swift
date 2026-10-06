/// 서버 청소 구역. 서버에는 내 구역 정보만 있고 학교 도면(층·칸)이 없어 도면은 앱이 가진 값을 쓴다.
final class CleaningAreaRepositoryImpl: CleaningAreaRepository {
    private let apiClient: APIClient
    private let floors: [FloorPlan]
    private let currentUserRepository: CurrentUserRepository

    // TODO: 서버가 도면을 내려주면 Mock 도면을 뺀다.
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
            // 응답에 누가 나인지 없어 로그인 때 저장한 이름으로 찾는다. 모르면 나를 따로 표시하지 않는다.
            return response.toDomain(floors: floors, myName: currentUserRepository.currentUser()?.name)
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_ASSIGNMENT") {
            return .unassigned
        }
    }
}
