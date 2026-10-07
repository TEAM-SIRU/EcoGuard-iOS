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
    /// 청소 알림. 켜면 알림 권한을 묻고 평일 인증 시작 시각에 알림을 건다(`UpdateCleaningReminderUseCase`).
    private(set) var isCleaningReminderOn: Bool
    /// 알림 권한이 거부돼 켜지 못했다는 안내(설정 앱 열기)를 띄웠는지.
    private(set) var isNotificationDeniedPresented = false
    /// 로그아웃 확인 팝업(Figma `12 전체 · 로그아웃 확인` 309:64)을 띄웠는지.
    private(set) var isLogoutConfirmPresented = false
    /// 로그아웃 요청 중. 이 동안에는 팝업을 닫거나 다시 누를 수 없다.
    private(set) var isLoggingOut = false

    private let fetchMyPageUseCase: FetchMyPageUseCase
    private let logoutUseCase: LogoutUseCase
    private let fetchCleaningReminderUseCase: FetchCleaningReminderUseCase
    private let updateCleaningReminderUseCase: UpdateCleaningReminderUseCase
    private let onLoggedOut: () -> Void
    private let logger = Logger(subsystem: "EcoGuard", category: "MyPage")
    private var isFetching = false
    /// 알림 권한을 묻는 중. 이 동안 스위치를 다시 바꾸지 않는다.
    private var isUpdatingCleaningReminder = false
    /// 로그아웃을 마치고 팝업이 내려가기를 기다리는 중.
    private var isAwaitingDismissAfterLogout = false

    /// `onLoggedOut`은 로그아웃을 마치고(실패해도) 팝업이 내려간 뒤 한 번 불린다. 로그인 화면으로 돌리는 일은 부르는 쪽이 맡는다.
    init(
        fetchMyPageUseCase: FetchMyPageUseCase,
        logoutUseCase: LogoutUseCase,
        fetchCleaningReminderUseCase: FetchCleaningReminderUseCase,
        updateCleaningReminderUseCase: UpdateCleaningReminderUseCase,
        state: State = .loading,
        onLoggedOut: @escaping () -> Void
    ) {
        self.fetchMyPageUseCase = fetchMyPageUseCase
        self.logoutUseCase = logoutUseCase
        self.fetchCleaningReminderUseCase = fetchCleaningReminderUseCase
        self.updateCleaningReminderUseCase = updateCleaningReminderUseCase
        self.state = state
        self.isCleaningReminderOn = fetchCleaningReminderUseCase.execute()
        self.onLoggedOut = onLoggedOut
    }

    func load() async {
        await refreshCleaningReminder()
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        let previous = state
        state = .loading
        do {
            state = .loaded(try await fetchMyPageUseCase.execute())
        } catch {
            // 탭을 떠나 취소되면 이전 화면으로 돌린다. 처음 불러오던 중이었다면 .loading으로 남겨 돌아왔을 때 다시 불러온다.
            guard !Task.isCancelled else {
                state = previous
                return
            }
            // 에러 본문에는 서버 응답이 섞일 수 있어 타입만 공개한다.
            logger.error("마이페이지 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }

    /// 화면을 그대로 둔 채 다시 조회한다. 신청·이의신청 흐름을 닫았을 때, 앱으로 돌아왔을 때 쓴다(이번 달 승인·신청 결과가 바뀔 수 있다).
    /// 불러온 화면이 없으면 `load()`와 같다. 실패하면 지금 화면을 유지한다.
    func refresh() async {
        // 설정 앱에서 알림을 끄고 돌아왔을 수 있다.
        await refreshCleaningReminder()
        guard case .loaded = state else {
            await load()
            return
        }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            state = .loaded(try await fetchMyPageUseCase.execute())
        } catch {
            guard !Task.isCancelled else { return }
            logger.error("마이페이지 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
        }
    }

    /// 켜면 알림 권한을 묻는다. 거부되면 스위치를 끈 채로 두고 설정 앱 안내를 띄운다.
    func setCleaningReminder(_ isOn: Bool) async {
        guard !isUpdatingCleaningReminder, isOn != isCleaningReminderOn else { return }
        isUpdatingCleaningReminder = true
        defer { isUpdatingCleaningReminder = false }
        isCleaningReminderOn = await updateCleaningReminderUseCase.execute(isOn: isOn)
        if isOn, !isCleaningReminderOn {
            isNotificationDeniedPresented = true
        }
    }

    func dismissNotificationDenied() {
        isNotificationDeniedPresented = false
    }

    /// 켜 두었어도 알림 권한이 없으면 끈 것으로 보여 준다.
    private func refreshCleaningReminder() async {
        guard !isUpdatingCleaningReminder else { return }
        let isOn = await fetchCleaningReminderUseCase.executeCheckingAuthorization()
        guard !isUpdatingCleaningReminder else { return }
        isCleaningReminderOn = isOn
    }

    func requestLogout() {
        guard !isLoggingOut, !isAwaitingDismissAfterLogout else { return }
        isLogoutConfirmPresented = true
    }

    func cancelLogout() {
        guard !isLoggingOut else { return }
        isLogoutConfirmPresented = false
    }

    /// 서버 요청이 실패해도 로그인 화면으로 보낸다(기기의 토큰은 저장소가 지운다).
    /// 팝업을 내리고, 다 내려가면(`logoutConfirmDidDismiss`) `onLoggedOut`을 부른다.
    func confirmLogout() async {
        guard isLogoutConfirmPresented, !isLoggingOut, !isAwaitingDismissAfterLogout else { return }
        isLoggingOut = true
        do {
            try await logoutUseCase.execute()
        } catch {
            logger.error("로그아웃 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
        }
        isLoggingOut = false
        isAwaitingDismissAfterLogout = true
        isLogoutConfirmPresented = false
    }

    /// 확인 팝업이 화면에서 다 내려간 뒤 부른다. 로그아웃을 마쳤으면 그때 `onLoggedOut`을 부른다.
    /// 팝업이 떠 있는 채로 화면을 바꾸면 팝업이 남거나 전환이 겹친다.
    func logoutConfirmDidDismiss() {
        guard isAwaitingDismissAfterLogout else { return }
        isAwaitingDismissAfterLogout = false
        onLoggedOut()
    }
}
