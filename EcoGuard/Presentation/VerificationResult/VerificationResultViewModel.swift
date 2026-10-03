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

    /// 화면이 나타날 때 부른다. 이미 불러왔으면 다시 부르지 않는다.
    func load() async {
        if case .loaded = state { return }
        await fetch()
    }

    /// 조회 실패 화면의 `결과 다시 확인`. 사진은 다시 보내지 않고 결과만 다시 조회한다.
    func retry() async {
        await fetch()
    }

    private func fetch() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            state = .loaded(try await fetchResultUseCase.execute(id: resultID))
        } catch where Self.isCancellation(error) {
            // 화면을 떠나 취소된 것은 조회 실패가 아니다. .loading에 두면 다시 나타날 때 `.task`가 새로 불러온다.
            return
        } catch {
            logger.error("인증 결과 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }

    /// `Task` 취소는 `CancellationError`로, 취소된 `URLSession` 요청은 `URLError.cancelled`로 온다.
    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }
}
