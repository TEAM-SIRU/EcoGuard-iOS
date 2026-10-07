import SwiftUI

/// 로그인 상태에 따라 첫 화면을 고른다.
struct RootView: View {
    private let container: DIContainer
    @State private var loginViewModel: LoginViewModel
    /// 학생 로그인 때마다 새로 만든다. 로그아웃 후 다른 계정으로 들어와도 이전 홈 데이터가 남지 않는다.
    @State private var homeViewModel: HomeViewModel?

    init(container: DIContainer) {
        self.container = container
        _loginViewModel = State(initialValue: container.makeLoginViewModel())
    }

    var body: some View {
        content
            #if DEBUG
            // 디버그 빌드 전용 화면 모음(#78). 로그인 화면에 진입 버튼을 띄우고, 실행 인자 `-ScreenGallery`면 바로 연다.
            .screenGallery(showsEntryButton: loginViewModel.state == .idle || loginViewModel.state == .failed)
            #endif
            .onChange(of: loginViewModel.state, initial: true) { _, state in
                homeViewModel = state == .loggedIn ? container.makeHomeViewModel() : nil
            }
            .task(id: loginViewModel.state) {
                // 학생이 메인에 들어오면 청소 알림을 정한 적이 없을 때만 권한을 묻는다(교사 화면에서는 묻지 않는다).
                guard loginViewModel.state == .loggedIn else { return }
                await container.makeRequestInitialCleaningReminderUseCase()?.execute()
            }
            .task(id: cleaningReminderSchedule) {
                // 앱 시작·홈 갱신으로 배정 구역·시각이 바뀌었거나 로그아웃(탈퇴·세션 만료 포함)했을 때만 다시 맞춘다.
                guard let schedule = cleaningReminderSchedule else { return }
                await container.makeSyncCleaningReminderUseCase().execute(schedule: schedule)
            }
            .task {
                // 토큰 재발급이 실패하면 저장소가 토큰을 지운 뒤 알린다. 마이페이지 로그아웃과 같은 경로로 로그인 화면에 돌린다.
                for await _ in container.authRepository.sessionExpirations() {
                    loginViewModel.didLogOut()
                }
            }
    }

    /// 청소 알림을 맞출 배정 구역·시각. 로그인 화면·교사 화면이면 `.some(nil)`(해제),
    /// 홈을 아직 불러오지 못했거나 실패했으면 nil(지금 예약을 그대로 둔다).
    private var cleaningReminderSchedule: CleaningReminderSchedule?? {
        guard loginViewModel.state == .loggedIn else { return .some(nil) }
        guard case .loaded(let summary) = homeViewModel?.state else { return nil }
        return .some(summary.status.cleaningReminderSchedule)
    }

    @ViewBuilder
    private var content: some View {
        switch loginViewModel.state {
        case .idle, .loading, .failed:
            LoginView(viewModel: loginViewModel)
        case .teacher:
            TeacherNoticeView(webAdminURL: container.webAdminURL) {
                await loginViewModel.logout()
            }
        case .loggedIn:
            if let homeViewModel {
                MainTabView(container: container, homeViewModel: homeViewModel, onLoggedOut: { loginViewModel.didLogOut() })
            }
        }
    }
}

#Preview {
    RootView(container: .preview())
}
