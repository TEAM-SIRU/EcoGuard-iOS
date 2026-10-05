import Foundation
import Observation
import os

@Observable
@MainActor
final class RecruitmentApplyViewModel {
    enum SubmitState: Equatable {
        case idle
        case submitting
        /// 네트워크 등으로 신청하지 못했다. 입력은 그대로 두고 다시 시도할 수 있다.
        case failed
    }

    let applicant: Applicant
    let capacityPerClass: Int
    var motivation = ""
    private(set) var submitState: SubmitState = .idle

    private let applyRecruitmentUseCase: ApplyRecruitmentUseCase
    private let logger = Logger(subsystem: "EcoGuard", category: "Recruitment")

    init(applicant: Applicant, capacityPerClass: Int, applyRecruitmentUseCase: ApplyRecruitmentUseCase) {
        self.applicant = applicant
        self.capacityPerClass = capacityPerClass
        self.applyRecruitmentUseCase = applyRecruitmentUseCase
    }

    var validation: ApplicationMotivation.Validation {
        ApplicationMotivation.validate(motivation)
    }

    var isSubmitting: Bool {
        submitState == .submitting
    }

    var canSubmit: Bool {
        validation == .valid && !isSubmitting
    }

    /// 신청한다. 결과 화면으로 넘어갈 결과를 돌려주고, 다시 시도해야 하면 nil.
    /// 진행 중에 다시 부르면 무시한다(중복 제출 방지).
    func submit() async -> ApplicationOutcome? {
        guard canSubmit else { return nil }
        submitState = .submitting
        do {
            let application = try await applyRecruitmentUseCase.execute(motivation: motivation)
            submitState = .idle
            return .applied(application)
        } catch RecruitmentError.full {
            submitState = .idle
            return .closedWhileApplying(reason: .full)
        } catch RecruitmentError.notInPeriod {
            submitState = .idle
            return .closedWhileApplying(reason: .periodEnded)
        } catch RecruitmentError.alreadyApplied(let application) {
            submitState = .idle
            return .applied(application)
        } catch {
            // 취소되면 실패 안내 없이 신청 전 화면으로 돌린다.
            guard !Task.isCancelled else {
                submitState = .idle
                return nil
            }
            logger.error("신청 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            submitState = .failed
            return nil
        }
    }
}
