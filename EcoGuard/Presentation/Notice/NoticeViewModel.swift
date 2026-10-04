import Foundation
import Observation
import os

@Observable
@MainActor
final class NoticeViewModel {
    enum State: Equatable {
        case loading
        case loaded([Notice])
        case failed
    }

    private(set) var state: State

    private let fetchNoticesUseCase: FetchNoticesUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Notice")
    private var isFetching = false

    init(fetchNoticesUseCase: FetchNoticesUseCase, state: State = .loading) {
        self.fetchNoticesUseCase = fetchNoticesUseCase
        self.state = state
    }

    /// 처음부터 불러온다. 조회 실패 화면의 `다시 시도`도 이것을 부른다.
    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        let previous = state
        state = .loading
        do {
            state = .loaded(try await fetchNoticesUseCase.execute())
        } catch {
            // 화면을 떠나 작업이 취소된 것은 조회 실패가 아니다. 이전 상태로 돌린다.
            // 처음 불러오던 중이었다면 .loading으로 남아 다시 나타날 때 `.task`가 새로 불러오고, 다시 시도 중이었다면 실패 화면을 유지한다.
            // 작업이 살아 있는데 온 취소 오류(`URLError.cancelled` 등)는 요청이 끊긴 것이라 실패로 둔다.
            guard !Task.isCancelled else {
                state = previous
                return
            }
            logger.error("공지 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }
}
