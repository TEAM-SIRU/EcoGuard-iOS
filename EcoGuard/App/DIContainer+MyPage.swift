import Foundation

extension DIContainer {
    /// 마이페이지. 로그아웃은 로그인과 같은 `authRepository`를 쓴다.
    /// `onLoggedOut`은 로그아웃을 마치고(실패해도) 확인 팝업이 내려간 뒤 불린다. 앱 셸에서 `LoginViewModel.didLogOut()`을 넘긴다.
    /// `repository`를 주지 않으면 서버 주소가 있을 때 실제 저장소, 없으면 Mock.
    func makeMyPageViewModel(
        repository: MyPageRepository? = nil,
        notificationSettingRepository: NotificationSettingRepository = NotificationSettingRepositoryImpl(),
        onLoggedOut: @escaping () -> Void
    ) -> MyPageViewModel {
        let repository: MyPageRepository = repository ?? apiClient.map { MyPageRepositoryImpl(apiClient: $0) } ?? MockMyPageRepository()
        return MyPageViewModel(
            fetchMyPageUseCase: FetchMyPageUseCase(myPageRepository: repository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
            fetchCleaningReminderUseCase: FetchCleaningReminderUseCase(notificationSettingRepository: notificationSettingRepository),
            updateCleaningReminderUseCase: UpdateCleaningReminderUseCase(notificationSettingRepository: notificationSettingRepository),
            onLoggedOut: onLoggedOut
        )
    }
}
