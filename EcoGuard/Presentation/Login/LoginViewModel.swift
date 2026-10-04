import Observation
import os

@Observable
@MainActor
final class LoginViewModel {
    enum State: Equatable {
        case idle
        case loading
        case failed
        case teacher
        case loggedIn
    }

    private(set) var state: State

    private let loginUseCase: LoginUseCase
    private let logoutUseCase: LogoutUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Login")

    init(loginUseCase: LoginUseCase, logoutUseCase: LogoutUseCase, state: State = .idle) {
        self.loginUseCase = loginUseCase
        self.logoutUseCase = logoutUseCase
        self.state = state
    }

    func login() async {
        guard state != .loading else { return }
        state = .loading
        do {
            switch try await loginUseCase.execute() {
            case .student:
                state = .loggedIn
            case .teacher:
                state = .teacher
            }
        } catch is CancellationError {
            state = .idle
        } catch AuthError.cancelled {
            state = .idle
        } catch {
            // 에러 본문에는 서버 응답·토큰이 섞일 수 있어 타입만 공개한다.
            logger.error("로그인 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }

    /// 서버 요청이 실패해도 로그인 화면으로 돌아간다. 기기의 토큰은 저장소가 지운다.
    func logout() async {
        do {
            try await logoutUseCase.execute()
        } catch {
            logger.error("로그아웃 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
        }
        state = .idle
    }
}
