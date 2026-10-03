import Foundation
import Observation
import os

/// 신청 결과 화면에 보여 줄 결과.
enum ApplicationOutcome: Hashable {
    enum ClosedReason: Hashable {
        /// 신청하는 사이 반 정원이 찼다.
        case full
        /// 신청하는 사이 신청 기간이 끝났다.
        case periodEnded
    }

    case applied(RecruitmentApplication)
    case closedWhileApplying(reason: ClosedReason)
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

/// 결과별 문구·아이콘. 문구는 `RecruitmentCopy.Result`에 있다.
struct ApplicationResultContent: Equatable {
    enum Icon: Equatable {
        case check
        case cross
    }

    let icon: Icon
    let title: String
    let message: String
    /// 홈으로 버튼을 primary로 둘지. 실패 계열은 secondary다.
    let isPrimaryAction: Bool

    init(outcome: ApplicationOutcome) {
        switch outcome {
        case .closedWhileApplying(let reason):
            icon = .cross
            title = RecruitmentCopy.Result.closedTitle
            message = switch reason {
            case .full: RecruitmentCopy.Result.closedMessage
            case .periodEnded: RecruitmentCopy.Result.periodEndedMessage
            }
            isPrimaryAction = false
        case .applied(let application):
            let applied = RecruitmentCopy.Result.appliedLine(
                order: application.order,
                appliedAt: RecruitmentFormatter.appliedAt(application.appliedAt)
            )
            icon = .check
            title = RecruitmentCopy.Result.approvedTitle
            message = "\(applied)\n"
                + (application.isAreaAssigned ? RecruitmentCopy.Result.areaAssigned : RecruitmentCopy.Result.awaitingAssignment)
            isPrimaryAction = true
        }
    }
}
