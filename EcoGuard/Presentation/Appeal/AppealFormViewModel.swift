import Foundation
import Observation
import os

@Observable
@MainActor
final class AppealFormViewModel {
    enum Phase: Equatable {
        /// 작성 중.
        case editing
        /// 작성 화면에서 보내는 중.
        case submitting
        /// 보내지 못했다. 제출 실패 화면(514:165)을 보여 주고 입력·사진은 그대로 둔다.
        case failed
        /// 제출 실패 화면의 `다시 보내기`로 보내는 중.
        case retrying
    }

    let target: AppealTarget
    var message = ""
    private(set) var photos: [AppealPhoto] = []
    private(set) var phase: Phase = .editing
    /// 고친 내용을 보내려 했는데 처음 보낸 이의신청이 이미 접수돼 있었다. 안내 팝업을 보여 준 뒤 완료 화면으로 간다.
    private(set) var alreadyReceivedAppeal: Appeal?
    private(set) var isShowingAlreadyReceived = false

    private let submitAppealUseCase: SubmitAppealUseCase
    private let requestID: String
    /// 실패·취소되어 접수 여부를 모르는 제출 내용. 서버에 닿았을 수 있어 다음 제출은 같은 `requestID`로 먼저 확인한다.
    private var unconfirmedAttempts: [AppealDraft] = []
    private let logger = Logger(subsystem: "EcoGuard", category: "Appeal")

    /// - Parameter phase: Preview에서 제출 실패 화면을 바로 보여 줄 때만 넘긴다.
    init(
        target: AppealTarget,
        submitAppealUseCase: SubmitAppealUseCase,
        requestID: String = UUID().uuidString,
        phase: Phase = .editing
    ) {
        self.target = target
        self.submitAppealUseCase = submitAppealUseCase
        self.requestID = requestID
        self.phase = phase
    }

    var validation: AppealMessage.Validation {
        AppealMessage.validate(message)
    }

    var isSubmitting: Bool {
        phase == .submitting || phase == .retrying
    }

    var canSubmit: Bool {
        validation == .valid && !isSubmitting
    }

    var canAddPhoto: Bool {
        photos.count < AppealMessage.maxPhotoCount && !isSubmitting
    }

    /// 카메라로 찍은 사진을 붙인다. 최대 개수를 넘으면 무시한다.
    func addPhoto(_ jpegData: Data) {
        guard canAddPhoto else { return }
        photos.append(AppealPhoto(id: UUID(), jpegData: jpegData))
    }

    func removePhoto(id: AppealPhoto.ID) {
        guard !isSubmitting else { return }
        photos.removeAll { $0.id == id }
    }

    /// 작성 화면의 `이의신청 보내기`. 완료 화면으로 넘어갈 이의신청을 돌려주고, 보내지 못했거나 이미 접수 안내를 띄웠으면 nil.
    /// 진행 중에 다시 부르면 무시한다(중복 제출 방지).
    func submit() async -> Appeal? {
        guard phase == .editing else { return nil }
        return await send(as: .submitting)
    }

    /// 제출 실패 화면의 `다시 보내기`. 이전 제출이 접수됐는지 먼저 확인한다.
    func retry() async -> Appeal? {
        guard phase == .failed else { return nil }
        return await send(as: .retrying)
    }

    /// 제출 실패 화면의 `내용 수정하기`·뒤로. 입력·사진을 그대로 둔 채 작성 화면으로 돌아간다.
    func editAfterFailure() {
        guard phase == .failed else { return }
        phase = .editing
    }

    /// 이미 접수 안내 팝업의 `확인`. 팝업이 내려간 뒤 `alreadyReceivedAppeal`로 완료 화면을 연다.
    func confirmAlreadyReceived() {
        isShowingAlreadyReceived = false
    }

    private func send(as sendingPhase: Phase) async -> Appeal? {
        guard validation == .valid else { return nil }
        let previousPhase = phase
        phase = sendingPhase
        let draft = AppealDraft(
            requestID: requestID,
            verificationID: target.verificationID,
            message: AppealMessage.trimmed(message),
            photos: photos
        )
        do {
            let result = try await submitAppealUseCase.execute(draft, unconfirmedAttempts: unconfirmedAttempts)
            unconfirmedAttempts = []
            phase = .editing
            switch result {
            case .submitted(let appeal):
                return appeal
            case .alreadyReceived(let appeal):
                alreadyReceivedAppeal = appeal
                isShowingAlreadyReceived = true
                return nil
            }
        } catch {
            unconfirmedAttempts.append(draft)
            // 제출은 `EcoButton`이 만든 Task에서 돌고 보내는 중에는 뒤로·스와이프를 막아 두어, 화면 이탈로는 취소되지 않는다.
            // 그래도 Task가 취소되면 실패 화면 대신 보내기 전 화면으로 되돌리고, 다음 제출에서 접수 여부를 확인한다.
            guard !Task.isCancelled else {
                phase = previousPhase
                return nil
            }
            logger.error("이의신청 제출 실패: \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
            phase = .failed
            return nil
        }
    }
}
