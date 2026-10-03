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
            .onChange(of: loginViewModel.state, initial: true) { _, state in
                homeViewModel = state == .loggedIn ? container.makeHomeViewModel() : nil
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
                MainTabView(container: container, homeViewModel: homeViewModel)
            }
        }
    }
}

#Preview {
    RootView(container: .preview())
}
