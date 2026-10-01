import Foundation
import Observation
import os

/// 신청 결과 화면에 보여 줄 결과.
enum ApplicationOutcome: Hashable {
    case applied(RecruitmentApplication)
    /// 신청하는 사이 정원이 차거나 기간이 끝났다.
    case closedWhileApplying
}

@Observable
@MainActor
final class ApplicationResultViewModel {
    enum State: Equatable {
        case loading
        case loaded(ApplicationOutcome)
        /// 신청 내역이 없다.
        case notApplied
        case failed
    }

    private(set) var state: State

    private let fetchMyApplicationUseCase: FetchMyApplicationUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Recruitment")
    private var isFetching = false

    /// `outcome`이 있으면(신청 직후) 그대로 보여 주고, 없으면(홈에서 열기) `load()`로 불러온다.
    init(outcome: ApplicationOutcome?, fetchMyApplicationUseCase: FetchMyApplicationUseCase) {
        self.fetchMyApplicationUseCase = fetchMyApplicationUseCase
        state = outcome.map(State.loaded) ?? .loading
    }

    func load() async {
        if case .loaded = state { return }
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        state = .loading
        do {
            if let application = try await fetchMyApplicationUseCase.execute() {
                state = .loaded(.applied(application))
            } else {
                state = .notApplied
            }
        } catch is CancellationError {
            state = .failed
        } catch {
            logger.error("신청 결과 조회 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            state = .failed
        }
    }
}

/// 결과별 문구·아이콘. 승인(246:112)·신청 중 마감(246:128)은 Figma 문구, 나머지는 Figma에 프레임이 없어 새로 썼다.
struct ApplicationResultContent: Equatable {
    enum Icon: Equatable {
        case check
        case cross
        case clock
    }

    let icon: Icon
    let title: String
    let message: String
    /// 홈으로 버튼을 primary로 둘지. 실패 계열은 secondary다.
    let isPrimaryAction: Bool

    init(outcome: ApplicationOutcome) {
        switch outcome {
        case .closedWhileApplying:
            icon = .cross
            title = "신청하지 못했어요"
            message = "신청하는 사이 모집 인원이 모두 찼어요.\n다음 모집 때 다시 신청해 주세요."
            isPrimaryAction = false
        case .applied(let application):
            let applied = "\(application.order)번째로 신청했어요 · \(RecruitmentFormatter.appliedAt(application.appliedAt))"
            switch application.status {
            case .approved:
                icon = .check
                title = "환경지킴이가 됐어요"
                message = application.isAreaAssigned
                    ? "\(applied)\n청소 구역이 배정됐어요. 홈에서 확인해 주세요."
                    : "\(applied)\n청소 구역이 배정되면 알려드려요."
                isPrimaryAction = true
            case .pending:
                icon = .clock
                title = "신청했어요"
                message = "\(applied)\n선생님이 확인하면 알려드려요."
                isPrimaryAction = true
            case .rejected:
                icon = .cross
                title = "신청이 반려됐어요"
                message = "\(applied)\n다음 모집 때 다시 신청해 주세요."
                isPrimaryAction = false
            }
        }
    }
}
