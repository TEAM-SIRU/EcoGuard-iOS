import Observation
import os

@Observable
@MainActor
final class MyPageViewModel {
    enum State: Equatable {
        case loading
        case loaded(MyPageSummary)
        case failed
    }

    private(set) var state: State
    /// 청소 알림. 알림 종류별 시점이 정해지기 전이라 서버·기기 알림과 연결하지 않고 화면 안에서만 켜고 끈다.
    // TODO: 알림 시점이 정해지면 설정 저장소와 알림 예약에 연결한다.
    var isCleaningReminderOn: Bool
    /// 로그아웃 확인 팝업(Figma `12 전체 · 로그아웃 확인` 309:64)을 띄웠는지.
    private(set) var isLogoutConfirmPresented = false
    /// 로그아웃 요청 중. 이 동안에는 팝업을 닫거나 다시 누를 수 없다.
    private(set) var isLoggingOut = false

    private let fetchMyPageUseCase: FetchMyPageUseCase
    private let logoutUseCase: LogoutUseCase
    private let onLoggedOut: () -> Void
    private let logger = Logger(subsystem: "EcoGuard", category: "MyPage")
    private var isFetching = false

    /// `onLoggedOut`은 로그아웃이 끝나면(실패해도) 한 번 불린다. 로그인 화면으로 돌아가는 일은 부르는 쪽이 맡는다.
    init(
        fetchMyPageUseCase: FetchMyPageUseCase,
        logoutUseCase: LogoutUseCase,
        state: State = .loading,
        isCleaningReminderOn: Bool = true,
        onLoggedOut: @escaping () -> Void
    ) {
        self.fetchMyPageUseCase = fetchMyPageUseCase
        self.logoutUseCase = logoutUseCase
        self.state = state
        self.isCleaningReminderOn = isCleaningReminderOn
        self.onLoggedOut = onLoggedOut
    }

    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        let previous = state
        state = .loading
        do {
            state = .loaded(try await fetchMyPageUseCase.execute())
        } catch is CancellationError {
            // 탭을 떠나 취소되면 이전 화면으로 돌린다. 처음 불러오던 중이었다면 .loading으로 남겨 돌아왔을 때 다시 불러온다.
            state = previous
        } catch {
            // 에러 본문에는 서버 응답이 섞일 수 있어 타입만 공개한다.
            logger.error("마이페이지 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }

    func requestLogout() {
        guard !isLoggingOut else { return }
        isLogoutConfirmPresented = true
    }

    func cancelLogout() {
        guard !isLoggingOut else { return }
        isLogoutConfirmPresented = false
    }

    /// 서버 요청이 실패해도 로그인 화면으로 보낸다(기기의 토큰은 저장소가 지운다).
    func confirmLogout() async {
        guard isLogoutConfirmPresented, !isLoggingOut else { return }
        isLoggingOut = true
        do {
            try await logoutUseCase.execute()
        } catch {
            logger.error("로그아웃 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
        }
        isLoggingOut = false
        isLogoutConfirmPresented = false
        onLoggedOut()
    }
}
