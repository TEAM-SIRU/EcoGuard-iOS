import Foundation

/// 서버 마이페이지. 이번 달 활동·구역 배정·신청 내역을 함께 불러 합친다.
/// 서버에 내 정보 API가 없어 이름은 로그인 때 저장한 사용자(`CurrentUserRepository`)에서 쓰고 학년·반은 비워 둔다(서버 요청 목록).
final class MyPageRepositoryImpl: MyPageRepository {
    private let apiClient: APIClient
    private let currentUserRepository: CurrentUserRepository
    private let now: () -> Date

    init(apiClient: APIClient, currentUserRepository: CurrentUserRepository, now: @escaping () -> Date = Date.init) {
        self.apiClient = apiClient
        self.currentUserRepository = currentUserRepository
        self.now = now
    }

    func fetchMyPage() async throws -> MyPageSummary {
        let apiClient = apiClient
        let month = HomeMapper.calendar.dateComponents([.year, .month], from: now())
        async let activity: MyActivityResponseDTO = apiClient.send(.myActivity(year: month.year ?? 0, month: month.month ?? 0))
        async let assignment = HomeRepositoryImpl.sendAllowingMissing(
            HomeDTO.Assignment.self,
            .Home.myAssignment,
            missingCode: "NO_ASSIGNMENT",
            apiClient: apiClient
        )
        async let application = HomeRepositoryImpl.sendAllowingMissing(
            HomeDTO.Application.self,
            .Home.myApplication,
            missingCode: "NO_APPLICATION",
            apiClient: apiClient
        )
        return MyPageMapper.summary(
            user: currentUserRepository.currentUser(),
            activity: try await activity,
            assignment: try await assignment,
            application: try await application
        )
    }
}
