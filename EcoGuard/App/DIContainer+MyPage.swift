import Foundation

extension DIContainer {
    /// 마이페이지. 로그아웃은 로그인과 같은 `authRepository`, 회원탈퇴는 `currentUserRepository`를 쓴다.
    /// `onLoggedOut`은 로그아웃을 마치고(실패해도) 확인 팝업이 내려간 뒤 불린다. 앱 셸에서 `LoginViewModel.didLogOut()`을 넘긴다.
    /// `repository`를 주지 않으면 서버 주소가 있을 때 실제 저장소, 없으면 Mock.
    func makeMyPageViewModel(
        repository: MyPageRepository? = nil,
        notificationSettingRepository: NotificationSettingRepository = NotificationSettingRepositoryImpl(),
        currentUserRepository: CurrentUserRepository? = nil,
        onLoggedOut: @escaping () -> Void
    ) -> MyPageViewModel {
        let currentUserRepository = currentUserRepository ?? self.currentUserRepository
        let repository: MyPageRepository = repository ?? apiClient.map { MyPageRepositoryImpl(apiClient: $0, currentUserRepository: currentUserRepository) } ?? MockMyPageRepository(store: mockStore)
        return MyPageViewModel(
            fetchMyPageUseCase: FetchMyPageUseCase(myPageRepository: repository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
            withdrawUseCase: WithdrawUseCase(currentUserRepository: currentUserRepository),
            fetchCleaningReminderUseCase: FetchCleaningReminderUseCase(
                notificationSettingRepository: notificationSettingRepository,
                cleaningReminderScheduler: cleaningReminderScheduler
            ),
            updateCleaningReminderUseCase: UpdateCleaningReminderUseCase(
                notificationSettingRepository: notificationSettingRepository,
                cleaningReminderScheduler: cleaningReminderScheduler
            ),
            onLoggedOut: onLoggedOut
        )
    }
}
