import Foundation
import Observation
import os

@Observable
@MainActor
final class AppealHistoryViewModel {
    enum State: Equatable {
        case loading
        case loaded([Appeal])
        case failed
    }

    private(set) var state: State

    private let fetchAppealsUseCase: FetchAppealsUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Appeal")
    private var isFetching = false

    init(fetchAppealsUseCase: FetchAppealsUseCase, state: State = .loading) {
        self.fetchAppealsUseCase = fetchAppealsUseCase
        self.state = state
    }

    /// 화면이 나타날 때·앱으로 돌아올 때 부른다. 이미 불러왔으면 목록을 둔 채 다시 조회해 검토 중이던 상태를 갱신한다.
    func load() async {
        switch state {
        case .loaded:
            await refresh()
        case .loading, .failed:
            await fetch()
        }
    }

    /// 조회 실패 화면의 `다시 시도`.
    func retry() async {
        await fetch()
    }

    /// 목록을 둔 채 다시 조회한다. 당겨서 새로고침·앱 복귀에서 쓴다. 실패하면 지금 목록을 유지한다.
    func refresh() async {
        guard case .loaded = state, !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            state = .loaded(try await fetchAppealsUseCase.execute())
        } catch {
            guard !Task.isCancelled else { return }
            logError(error)
        }
    }

    private func fetch() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            state = .loaded(try await fetchAppealsUseCase.execute())
        } catch {
            // 화면을 떠나 작업이 취소된 것은 조회 실패가 아니다. .loading에 두면 다시 나타날 때 `.task`가 새로 불러온다.
            guard !Task.isCancelled else { return }
            logError(error)
            state = .failed
        }
    }

    private func logError(_ error: Error) {
        logger.error("이의신청 내역 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
