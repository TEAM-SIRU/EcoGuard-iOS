import Foundation

/// 서버 마이페이지. 내 정보·이번 달 활동·구역 배정·신청 내역을 함께 불러 합친다.
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
        // 나머지 요청은 위에서 이미 보냈다. 기다리는 동안 내 정보를 받는다.
        let user = try await currentUserRepository.fetchCurrentUser()
        return MyPageMapper.summary(
            user: user,
            activity: try await activity,
            assignment: try await assignment,
            application: try await application
        )
    }
}
