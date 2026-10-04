import Foundation

extension DIContainer {
    /// 마이페이지. 로그아웃은 로그인과 같은 저장소를 써야 해서 `LogoutUseCase`를 받는다.
    /// `onLoggedOut`은 로그아웃이 끝나면(실패해도) 불린다. 로그인 화면으로 돌리는 연결은 앱 셸 이슈에서 한다.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다.
    func makeMyPageViewModel(
        logoutUseCase: LogoutUseCase,
        repository: MyPageRepository = MockMyPageRepository(),
        onLoggedOut: @escaping () -> Void
    ) -> MyPageViewModel {
        MyPageViewModel(
            fetchMyPageUseCase: FetchMyPageUseCase(myPageRepository: repository),
            logoutUseCase: logoutUseCase,
            onLoggedOut: onLoggedOut
        )
    }
}
