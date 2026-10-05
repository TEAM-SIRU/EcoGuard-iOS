import AuthenticationServices
import UIKit

/// OAuth 콜백을 받을 주소 형태.
enum WebAuthenticationCallback: Equatable {
    case customScheme(String)
    /// 앱의 Associated Domains(`webcredentials:`)에 `host`가 있어야 한다. iOS 17.4부터 쓸 수 있다.
    case https(host: String, path: String)
}

/// 웹 인증 창. 테스트에서 실제 창 대신 정해진 콜백 주소를 돌려주도록 프로토콜 뒤에 둔다.
protocol WebAuthenticationSession {
    /// 콜백 주소를 돌려준다. 사용자가 창을 닫으면 `AuthError.cancelled`를 던진다.
    func authenticate(url: URL, callback: WebAuthenticationCallback) async throws -> URL
}

/// `ASWebAuthenticationSession` 래퍼. 한 번에 하나의 인증만 진행한다.
final class SystemWebAuthenticationSession: NSObject, WebAuthenticationSession {
    struct StartFailedError: Error {}
    /// iOS 17.4 미만에서 https 콜백을 요청했다.
    struct UnsupportedCallbackError: Error {}

    private var session: ASWebAuthenticationSession?
    private var continuation: CheckedContinuation<URL, Error>?

    func authenticate(url: URL, callback: WebAuthenticationCallback) async throws -> URL {
        // 진행 중인 인증이 있으면 사용자가 닫은 것으로 끝낸다(로그인 버튼은 진행 중 다시 눌리지 않는다).
        finish(.failure(AuthError.cancelled))
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                start(url: url, callback: callback, continuation: continuation)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    private func start(url: URL, callback: WebAuthenticationCallback, continuation: CheckedContinuation<URL, Error>) {
        let completion: ASWebAuthenticationSession.CompletionHandler = { [weak self] callbackURL, error in
            Task { @MainActor in
                if let callbackURL {
                    self?.finish(.success(callbackURL))
                } else {
                    self?.finish(.failure(Self.mapError(error)))
                }
            }
        }
        let session: ASWebAuthenticationSession
        if #available(iOS 17.4, *) {
            let asCallback: ASWebAuthenticationSession.Callback = switch callback {
            case let .customScheme(scheme): .customScheme(scheme)
            case let .https(host, path): .https(host: host, path: path)
            }
            session = ASWebAuthenticationSession(url: url, callback: asCallback, completionHandler: completion)
        } else {
            guard case let .customScheme(scheme) = callback else {
                continuation.resume(throwing: UnsupportedCallbackError())
                return
            }
            session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme, completionHandler: completion)
        }
        session.presentationContextProvider = self
        // 공용 기기에서 이전 사용자의 dataGSM 로그인이 남지 않게 쿠키를 공유하지 않는다.
        session.prefersEphemeralWebBrowserSession = true
        self.session = session
        self.continuation = continuation
        if !session.start() {
            finish(.failure(StartFailedError()))
        }
    }

    /// 사용자가 창을 닫은 것은 `AuthError.cancelled`, 그 밖의 에러는 그대로 둔다.
    nonisolated static func mapError(_ error: Error?) -> Error {
        guard let error else { return StartFailedError() }
        if let webError = error as? ASWebAuthenticationSessionError, webError.code == .canceledLogin {
            return AuthError.cancelled
        }
        return error
    }

    /// 완료 콜백과 작업 취소가 겹쳐도 continuation은 한 번만 재개한다.
    private func finish(_ result: Result<URL, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        let session = self.session
        self.session = nil
        if case .failure = result {
            session?.cancel()
        }
        continuation.resume(with: result)
    }
}

extension SystemWebAuthenticationSession: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
    }
}
