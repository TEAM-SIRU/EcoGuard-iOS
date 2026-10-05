/// 서버 청소 구역. 서버에는 내 구역 정보만 있고 학교 도면(층·칸)이 없어 도면은 앱이 가진 값을 쓴다.
final class CleaningAreaRepositoryImpl: CleaningAreaRepository {
    private let apiClient: APIClient
    private let floors: [FloorPlan]
    private let myName: String

    // TODO: 서버가 도면과 내 정보(이름)를 내려주면 기본값을 뺀다. 그 전까지 Mock 도면·이름을 쓴다.
    init(
        apiClient: APIClient,
        floors: [FloorPlan] = MockCleaningAreaRepository.Fixture.floors,
        myName: String = MockRecruitmentRepository.Fixture.applicant.name
    ) {
        self.apiClient = apiClient
        self.floors = floors
        self.myName = myName
    }

    func fetchCleaningArea() async throws -> CleaningAreaSummary {
        do {
            let response: MyAssignmentResponseDTO = try await apiClient.send(.myAssignment)
            return try response.toDomain(floors: floors, myName: myName)
        } catch let error as APIError where error == .server(statusCode: 404, code: "NO_ASSIGNMENT") {
            return .unassigned
        }
    }
}
