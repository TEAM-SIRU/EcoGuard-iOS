import SwiftUI

/// 로그인 상태에 따라 첫 화면을 고른다.
struct RootView: View {
    @State private var loginViewModel: LoginViewModel
    private let webAdminURL: URL?

    init(container: DIContainer) {
        _loginViewModel = State(initialValue: container.makeLoginViewModel())
        webAdminURL = container.webAdminURL
    }

    var body: some View {
        switch loginViewModel.state {
        case .idle, .loading, .failed:
            LoginView(viewModel: loginViewModel)
        case .teacher:
            TeacherNoticeView(webAdminURL: webAdminURL) {
                await loginViewModel.logout()
            }
        case .loggedIn:
            MainPlaceholderView()
        }
    }
}

#Preview {
    RootView(container: .preview())
}
