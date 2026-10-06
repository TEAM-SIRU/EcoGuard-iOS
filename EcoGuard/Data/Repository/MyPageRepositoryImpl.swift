import Foundation

/// 서버 마이페이지. 내 정보·이번 달 활동·구역 배정·현재 공고(신청했으면 내 신청)를 함께 불러 합친다.
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
        async let recruitment = HomeRepositoryImpl.sendAllowingMissing(
            HomeDTO.CurrentRecruitment.self,
            .Home.currentRecruitment,
            missingCode: "NO_ACTIVE_RECRUITMENT",
            apiClient: apiClient
        )
        // 나머지 요청은 위에서 이미 보냈다. 기다리는 동안 내 정보를 받는다.
        // 이름·학반은 보조 정보라 받지 못해도(저장한 값도 없음) 화면은 이름 없이 보여 준다.
        let user = try? await currentUserRepository.fetchCurrentUser()
        // `applications/me`는 가장 최근 신청이라 현재 공고에 신청했을 때만 본다(홈과 같다).
        let currentRecruitment = try await recruitment
        let application = currentRecruitment?.alreadyApplied == true
            ? try await HomeRepositoryImpl.sendAllowingMissing(HomeDTO.Application.self, .Home.myApplication, missingCode: "NO_APPLICATION", apiClient: apiClient)
            : nil
        return MyPageMapper.summary(
            user: user,
            activity: try await activity,
            assignment: try await assignment,
            recruitment: currentRecruitment,
            application: application
        )
    }
}
