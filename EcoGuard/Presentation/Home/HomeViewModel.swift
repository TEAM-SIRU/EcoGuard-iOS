import Foundation
import Observation
import os

@Observable
@MainActor
final class HomeViewModel {
    enum State: Equatable {
        case loading
        case loaded(HomeSummary)
        case failed
    }

    private(set) var state: State

    private let fetchHomeUseCase: FetchHomeUseCase
    private let dismissNoticeUseCase: DismissNoticeUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Home")
    private var isFetching = false

    init(fetchHomeUseCase: FetchHomeUseCase, dismissNoticeUseCase: DismissNoticeUseCase, state: State = .loading) {
        self.fetchHomeUseCase = fetchHomeUseCase
        self.dismissNoticeUseCase = dismissNoticeUseCase
        self.state = state
    }

    /// 다시 조회할 시각(인증 시작·마감). 그 사이에 상태가 바뀌므로 화면이 이 시각에 `refresh()`를 부른다.
    var nextRefreshDate: Date? {
        guard case .loaded(let summary) = state, case .active(let cleaning) = summary.status else { return nil }
        return cleaning.today.verification.nextRefreshDate
    }

    /// 스켈레톤을 보여 주며 처음부터 불러온다.
    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        let previous = state
        state = .loading
        do {
            state = .loaded(try await fetchHomeUseCase.execute())
        } catch is CancellationError {
            // 화면을 떠나 취소되면 .loading에 남지 않게 이전 화면으로 돌린다. 처음 불러오던 중이었다면 다시 시도할 수 있게 실패로 둔다.
            state = previous == .loading ? .failed : previous
        } catch {
            logError(error)
            state = .failed
        }
    }

    /// 화면을 그대로 둔 채 다시 조회한다. 인증 시작·마감 시각, 앱 복귀, 당겨서 새로고침에서 쓴다.
    /// 불러온 화면이 없으면 `load()`와 같다. 실패하면 지금 화면을 유지한다.
    func refresh() async {
        guard case .loaded = state else {
            await load()
            return
        }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            state = .loaded(try await fetchHomeUseCase.execute())
        } catch is CancellationError {
            return
        } catch {
            logError(error)
        }
    }

    func retry() async {
        await load()
    }

    /// 가운데 카메라 버튼을 켤지. 구역을 배정받아 활동 중일 때만 켠다.
    var isCameraAvailable: Bool {
        guard case .loaded(let summary) = state, case .active = summary.status else { return false }
        return true
    }

    /// 인증 버튼을 켤지. 마감이 지나면 다시 조회되기 전에도 끈다.
    func canVerify(at date: Date) -> Bool {
        guard case .loaded(let summary) = state, case .active(let cleaning) = summary.status else { return false }
        return cleaning.today.verification.acceptsSubmission(at: date)
    }

    /// 화면에서 먼저 숨기고 서버에 닫음을 알린다.
    func dismissNotice() async {
        guard case .loaded(let summary) = state, let notice = summary.notice else { return }
        state = .loaded(summary.removingNotice())
        await dismissNoticeUseCase.execute(noticeID: notice.id)
    }

    private func logError(_ error: Error) {
        logger.error("홈 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
