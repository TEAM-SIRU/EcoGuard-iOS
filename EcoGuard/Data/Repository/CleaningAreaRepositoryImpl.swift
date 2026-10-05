/// 서버 청소 구역. 서버에는 내 구역 정보만 있고 학교 도면(층·칸)이 없어 도면은 앱이 가진 값을 쓴다.
final class CleaningAreaRepositoryImpl: CleaningAreaRepository {
    private let apiClient: APIClient
    private let floors: [FloorPlan]
    private let myName: String?

    // TODO: 서버가 도면을 내려주면 Mock 도면을 뺀다.
    // TODO: #55에서 로그인 응답의 사용자 이름을 저장하면 그 이름을 `myName`으로 넘긴다. 그 전까지 nil(나를 따로 표시하지 않음).
    init(
        apiClient: APIClient,
        floors: [FloorPlan] = MockCleaningAreaRepository.Fixture.floors,
        myName: String? = nil
    ) {
        self.apiClient = apiClient
        self.floors = floors
        self.myName = myName
    }

    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        do {
            let response: MyAssignmentResponseDTO = try await apiClient.send(.myAssignment)
            return response.toDomain(floors: floors, myName: myName)
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_ASSIGNMENT") {
            return .unassigned
        }
    }
}
