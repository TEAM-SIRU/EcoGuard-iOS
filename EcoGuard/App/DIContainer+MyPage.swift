import Foundation

extension DIContainer {
    /// 마이페이지. 로그아웃은 로그인과 같은 `authRepository`를 쓴다.
    /// `onLoggedOut`은 로그아웃을 마치고(실패해도) 확인 팝업이 내려간 뒤 불린다. 앱 셸에서 `LoginViewModel.didLogOut()`을 넘긴다.
    // TODO: 서버 연동 때 마이페이지 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다.
    func makeMyPageViewModel(
        repository: MyPageRepository = MockMyPageRepository(),
        notificationSettingRepository: NotificationSettingRepository = NotificationSettingRepositoryImpl(),
        onLoggedOut: @escaping () -> Void
    ) -> MyPageViewModel {
        MyPageViewModel(
            fetchMyPageUseCase: FetchMyPageUseCase(myPageRepository: repository),
            logoutUseCase: LogoutUseCase(authRepository: authRepository),
            fetchCleaningReminderUseCase: FetchCleaningReminderUseCase(notificationSettingRepository: notificationSettingRepository),
            updateCleaningReminderUseCase: UpdateCleaningReminderUseCase(notificationSettingRepository: notificationSettingRepository),
            onLoggedOut: onLoggedOut
        )
    }
}
