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
            .task {
                // 토큰 재발급이 실패하면 저장소가 토큰을 지운 뒤 알린다. 마이페이지 로그아웃과 같은 경로로 로그인 화면에 돌린다.
                for await _ in container.authRepository.sessionExpirations() {
                    loginViewModel.didLogOut()
                }
            }
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
