import Foundation
import Observation
import os

@Observable
@MainActor
final class VerificationResultViewModel {
    enum State: Equatable {
        case loading
        case loaded(VerificationResult)
        case failed
    }

    private(set) var state: State

    private let resultID: String
    private let fetchResultUseCase: FetchVerificationResultUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "VerificationResult")
    private var isFetching = false

    init(resultID: String, fetchResultUseCase: FetchVerificationResultUseCase, state: State = .loading) {
        self.resultID = resultID
        self.fetchResultUseCase = fetchResultUseCase
        self.state = state
    }

    /// 화면이 나타날 때·앱으로 돌아올 때 부른다. 결과가 나왔으면 다시 부르지 않고, 검수 중이면 화면을 둔 채 다시 조회한다.
    func load() async {
        switch state {
        case .loaded(let result) where result.status == .processing:
            await refresh()
        case .loaded:
            return
        case .loading, .failed:
            await fetch()
        }
    }

    /// 조회 실패 화면의 `결과 다시 확인`. 사진은 다시 보내지 않고 결과만 다시 조회한다.
    func retry() async {
        await fetch()
    }

    /// 검수 중 화면을 그대로 둔 채 다시 조회한다. 당겨서 새로고침·앱 복귀에서 쓴다. 실패하면 지금 화면을 유지한다.
    func refresh() async {
        guard case .loaded(let result) = state, result.status == .processing else { return }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            state = .loaded(try await fetchResultUseCase.execute(id: resultID))
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
            state = .loaded(try await fetchResultUseCase.execute(id: resultID))
        } catch {
            // 화면을 떠나 작업이 취소된 것은 조회 실패가 아니다. .loading에 두면 다시 나타날 때 `.task`가 새로 불러온다.
            // 작업이 살아 있는데 온 취소 오류(`URLError.cancelled` 등)는 요청이 끊긴 것이라 실패로 둔다.
            guard !Task.isCancelled else { return }
            logError(error)
            state = .failed
        }
    }

    private func logError(_ error: Error) {
        logger.error("인증 결과 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
