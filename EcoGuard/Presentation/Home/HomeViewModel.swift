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

    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            state = .loaded(try await fetchHomeUseCase.execute())
        } catch is CancellationError {
            return
        } catch {
            logger.error("홈 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }

    func retry() async {
        await load()
    }

    /// 화면에서 먼저 숨기고 서버에 닫음을 알린다.
    func dismissNotice() async {
        guard case .loaded(let summary) = state, let notice = summary.notice else { return }
        state = .loaded(summary.removingNotice())
        await dismissNoticeUseCase.execute(noticeID: notice.id)
    }
}
