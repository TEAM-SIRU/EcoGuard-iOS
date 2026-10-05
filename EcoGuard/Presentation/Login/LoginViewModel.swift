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
        } catch AuthError.cancelled {
            state = .idle
        } catch {
            // 작업이 취소되면 실패 안내 없이 로그인 전 화면으로 돌린다.
            guard !Task.isCancelled else {
                state = .idle
                return
            }
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

    /// 다른 화면(마이페이지)에서 로그아웃을 마쳤을 때 로그인 화면으로만 돌린다. 저장소는 다시 부르지 않는다.
    func didLogOut() {
        state = .idle
    }
}
