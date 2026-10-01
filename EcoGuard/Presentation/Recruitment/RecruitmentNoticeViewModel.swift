import Foundation
import Observation
import os

@Observable
@MainActor
final class RecruitmentNoticeViewModel {
    enum State: Equatable {
        case loading
        case loaded(RecruitmentDetail, Applicant)
        /// 진행 중이거나 최근 모집 공고가 없다.
        case empty
        case failed
    }

    private(set) var state: State

    private let fetchRecruitmentUseCase: FetchRecruitmentUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Recruitment")
    private var isFetching = false

    init(fetchRecruitmentUseCase: FetchRecruitmentUseCase, state: State = .loading) {
        self.fetchRecruitmentUseCase = fetchRecruitmentUseCase
        self.state = state
    }

    /// 다시 조회할 시각. 신청 기간 전이면 시작, 신청 중이면 마감 시각에 서버 상태(`phase`)가 바뀐다.
    var nextRefreshDate: Date? {
        guard case .loaded(let detail, _) = state else { return nil }
        switch detail.status {
        case .upcoming: return detail.startDate
        case .open: return detail.endDate
        case .full, .applied, .ended: return nil
        }
    }

    /// 신청 버튼을 켤지. 서버가 신청 가능으로 내려준 경우에만, 마감 시각 전까지 켠다(기기 시간은 다시 조회되기 전 UI 힌트로만 쓴다).
    func canApply(at date: Date) -> Bool {
        guard case .loaded(let detail, _) = state, detail.status == .open else { return false }
        return date < detail.endDate
    }

    /// 스켈레톤을 보여 주며 처음부터 불러온다.
    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            state = try await fetchedState()
        } catch is CancellationError {
            // 화면을 떠나 취소되면 .loading에 남지 않게 다시 시도할 수 있는 실패로 둔다.
            state = .failed
        } catch {
            logError(error)
            state = .failed
        }
    }

    /// 화면을 그대로 둔 채 다시 조회한다. 신청 시작·마감 시각, 앱 복귀, 당겨서 새로고침, 신청 직후에 쓴다.
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
            state = try await fetchedState()
        } catch is CancellationError {
            return
        } catch {
            logError(error)
        }
    }

    func retry() async {
        await load()
    }

    private func fetchedState() async throws -> State {
        let result = try await fetchRecruitmentUseCase.execute()
        guard let detail = result.detail else { return .empty }
        return .loaded(detail, result.applicant)
    }

    private func logError(_ error: Error) {
        logger.error("모집 공고 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
