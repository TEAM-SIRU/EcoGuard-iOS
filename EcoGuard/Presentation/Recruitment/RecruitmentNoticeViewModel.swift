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

    func load() async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            let result = try await fetchRecruitmentUseCase.execute()
            if let detail = result.detail {
                state = .loaded(detail, result.applicant)
            } else {
                state = .empty
            }
        } catch is CancellationError {
            // 화면을 떠나 취소되면 .loading에 남지 않게 다시 시도할 수 있는 실패로 둔다.
            state = .failed
        } catch {
            logger.error("모집 공고 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }

    func retry() async {
        await load()
    }
}
