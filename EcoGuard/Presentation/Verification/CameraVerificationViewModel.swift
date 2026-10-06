import Foundation
import Observation
import os
import UIKit

/// 청소 인증 흐름: 촬영 안내 → 촬영 → 확인 → 제출.
/// 인증 가능 여부·마감은 서버 값으로 판단한다. 마감 도달 시 화면 전환은 서버 시각으로 보정한 시계로 계산한다.
@Observable
@MainActor
final class CameraVerificationViewModel {
    enum State: Equatable {
        case loading
        case loadFailed
        case guide
        case capturing
        case confirming(CapturedPhoto)
        case uploading(CapturedPhoto)
        case uploadFailed(CapturedPhoto)
        case submitted(CapturedPhoto, submittedAt: Date)
        /// 마감이 지나 새 사진을 보낼 수 없다.
        case timedOut
    }

    /// 화면 위에 띄우는 안내 시트.
    enum Sheet: Equatable {
        case outsideWindow(VerificationClosedReason)
        /// 서버가 제출 시각·검수 상태를 주지 않으면 nil이다.
        case alreadySubmitted(submittedAt: Date?, status: VerificationResult.Status?)
        case permissionRequired

        /// 확인하면 인증 흐름을 닫는 시트. 권한 안내는 닫아도 촬영 안내에 머문다.
        var closesFlow: Bool {
            self != .permissionRequired
        }
    }

    /// 찍은 사진. 업로드용 JPEG와 화면 표시용 이미지를 함께 둔다.
    struct CapturedPhoto: Equatable {
        var photo: VerificationPhoto
        let image: UIImage

        /// 한 번이라도 보내기 시작했는지. 서버는 마감 전에 시작한 사진의 재시도를 마감 후 유예 시간까지 받으므로,
        /// 그때까지 이 사진은 시간 초과로 보내지 않는다.
        var hasStartedUpload: Bool {
            photo.uploadStartedAt != nil
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.photo == rhs.photo
        }
    }

    private(set) var state: State
    private(set) var sheet: Sheet?
    private(set) var session: VerificationSession?
    /// 이번에 낸 인증. 앱 셸이 홈 갱신 전에 `제출한 인증 보기`를 열 때 쓴다.
    private(set) var submission: VerificationSubmission?

    /// 카메라 세션·셔터. 촬영 화면이 그대로 쓴다.
    let capture: CameraCapture

    private let fetchSessionUseCase: FetchVerificationSessionUseCase
    private let submitPhotoUseCase: SubmitVerificationPhotoUseCase
    private let permission: CameraPermission
    private let now: () -> Date
    /// 서버 시각 - 기기 시각. 응답 지연만큼의 오차는 남지만 기기 시계를 바꿔 마감을 넘기는 것은 막는다.
    private var clockOffset: TimeInterval = 0
    private let logger = Logger(subsystem: "EcoGuard", category: "Verification")

    init(
        fetchSessionUseCase: FetchVerificationSessionUseCase,
        submitPhotoUseCase: SubmitVerificationPhotoUseCase,
        camera: CameraService,
        permission: CameraPermission,
        now: @escaping () -> Date = Date.init,
        state: State = .loading,
        sheet: Sheet? = nil,
        session: VerificationSession? = nil
    ) {
        self.fetchSessionUseCase = fetchSessionUseCase
        self.submitPhotoUseCase = submitPhotoUseCase
        capture = CameraCapture(camera: camera)
        self.permission = permission
        self.now = now
        self.state = state
        self.sheet = sheet
        if let session {
            apply(session)
        }
    }

    /// 서버가 정한 마감 시각. 인증 가능하고 서버가 마감 시각을 줬을 때만 있다.
    var deadline: Date? {
        guard case .open(let deadline) = session?.availability else { return nil }
        return deadline
    }

    /// 시간 초과를 다시 확인할 시각(서버 기준): 마감, 마감 후 재시도 유예가 끝나는 시각.
    var expiryCheckDates: [Date] {
        deadline.map { [$0, $0.addingTimeInterval(VerificationSession.lateRetryGrace)] } ?? []
    }

    private var isOpen: Bool {
        guard case .open = session?.availability else { return false }
        return true
    }

    /// 서버 기준 지금 시각.
    var serverNow: Date {
        serverDate(fromDevice: now())
    }

    /// 기기 시각을 서버 기준으로 바꾼다. 화면의 남은 시간 표시에 쓴다.
    func serverDate(fromDevice date: Date) -> Date {
        date.addingTimeInterval(clockOffset)
    }

    var isTakingPhoto: Bool { capture.isTakingPhoto }
    var isCameraReady: Bool { capture.isCameraReady }
    var isCameraUnavailable: Bool { capture.isCameraUnavailable }
    var captureFailureCount: Int { capture.captureFailureCount }

    /// 셔터를 누를 수 있는지.
    var canTakePhoto: Bool {
        state == .capturing && capture.canTakePhoto
    }

    var canSwitchCamera: Bool {
        state == .capturing && capture.canSwitchCamera
    }

    func load() async {
        let previous = state
        state = .loading
        do {
            let session = try await fetchSessionUseCase.execute()
            apply(session)
            state = .guide
            switch session.availability {
            case .open:
                sheet = nil
                expireIfNeeded()
            case .outsideWindow(let reason):
                sheet = .outsideWindow(reason)
            case .alreadySubmitted(let submittedAt, let status):
                sheet = .alreadySubmitted(submittedAt: submittedAt, status: status)
            }
        } catch {
            // 화면을 떠나 취소되면 이전 화면으로 돌린다. 처음 불러오던 중이었다면 .loading으로 남겨 다시 나타날 때 `.task`가 새로 불러온다.
            guard !Task.isCancelled else {
                state = previous
                return
            }
            logError("인증 정보 조회 실패", error)
            state = .loadFailed
        }
    }

    /// 촬영 안내의 `촬영하기`. 권한이 없으면 묻고, 거부돼 있으면 설정 안내 시트를 띄운다.
    func startCapture() async {
        guard state == .guide, isOpen else { return }
        guard !expireIfNeeded() else { return }
        switch permission.status {
        case .authorized:
            state = .capturing
        case .notDetermined:
            if await permission.requestAccess() {
                guard state == .guide, !expireIfNeeded() else { return }
                state = .capturing
            } else {
                sheet = .permissionRequired
            }
        case .denied:
            sheet = .permissionRequired
        }
    }

    /// 촬영 화면 닫기. 촬영 안내로 돌아간다.
    func cancelCapture() {
        guard state == .capturing else { return }
        state = .guide
    }

    func takePhoto() async {
        guard canTakePhoto, let output = await capture.takePhoto() else { return }
        guard state == .capturing else { return }
        let photo = VerificationPhoto(id: UUID(), jpegData: output.jpegData, capturedAt: serverNow)
        state = .confirming(CapturedPhoto(photo: photo, image: output.image))
    }

    func switchCamera() async {
        guard canSwitchCamera else { return }
        await capture.switchCamera()
    }

    /// 확인 화면의 `다시 찍기`·뒤로가기. 새 사진이므로 마감이 지났으면 시간 초과로 보낸다.
    func retake() {
        guard case .confirming = state else { return }
        guard serverNow < (deadline ?? .distantFuture) else {
            state = .timedOut
            return
        }
        state = .capturing
    }

    /// 업로드 실패 화면의 뒤로가기. 같은 사진의 확인 화면으로 돌아가 다시 찍을지 고를 수 있게 한다.
    func returnToConfirm() {
        guard case .uploadFailed(let photo) = state else { return }
        state = .confirming(photo)
    }

    /// 확인 화면의 `보내기`, 업로드 실패 화면의 `같은 사진 다시 보내기`.
    /// 같은 사진은 같은 `photo.id`(재전송 키)와 처음 시작 시각으로 보내 마감 전에 시작한 업로드를 유예 시간까지 이어 갈 수 있게 한다.
    func submit() async {
        // 화면이 마감 시각 갱신을 놓친 채 눌렀으면 보내지 않는다.
        guard !expireIfNeeded() else { return }
        var captured: CapturedPhoto
        switch state {
        case .confirming(let photo), .uploadFailed(let photo):
            captured = photo
        default:
            return
        }
        if captured.photo.uploadStartedAt == nil {
            captured.photo.uploadStartedAt = serverNow
        }
        // 취소되면 돌아갈 화면. 업로드를 시작한 사진으로 남겨 마감 후 유예 시간 안에 다시 보내도 시간 초과로 보지 않게 한다.
        let previous: State = if case .confirming = state { .confirming(captured) } else { .uploadFailed(captured) }
        state = .uploading(captured)
        do {
            let submission = try await submitPhotoUseCase.execute(captured.photo)
            self.submission = submission
            state = .submitted(captured, submittedAt: submission.submittedAt)
        } catch VerificationError.deadlinePassed {
            state = .timedOut
        } catch VerificationError.alreadySubmitted(let submittedAt, let status) {
            state = .uploadFailed(captured)
            sheet = .alreadySubmitted(submittedAt: submittedAt, status: status)
        } catch VerificationError.vacation {
            state = .uploadFailed(captured)
            sheet = .outsideWindow(.vacation)
        } catch {
            guard !Task.isCancelled else {
                state = previous
                return
            }
            logError("인증 사진 업로드 실패", error)
            state = .uploadFailed(captured)
        }
    }

    /// 시간 초과 화면의 `업로드 상태 확인`. 서버에 제출된 사진이 있으면 이미 제출 시트를 띄운다.
    func checkUploadStatus() async {
        guard state == .timedOut else { return }
        do {
            let session = try await fetchSessionUseCase.execute()
            apply(session)
            if case .alreadySubmitted(let submittedAt, let status) = session.availability {
                sheet = .alreadySubmitted(submittedAt: submittedAt, status: status)
            }
        } catch {
            guard !Task.isCancelled else { return }
            logError("업로드 상태 조회 실패", error)
        }
    }

    func dismissSheet() {
        sheet = nil
    }

    /// 마감까지 남은 시간(서버 기준). 마감이 없으면 nil.
    func timeUntilDeadline() -> TimeInterval? {
        deadline.map { $0.timeIntervalSince(serverNow) }
    }

    /// 마감이 지났으면 시간 초과로 바꾼다. 바꿨으면 true. 화면이 `expiryCheckDates`·앱 복귀 때 부른다.
    /// 업로드를 시작한 사진(실패·그 뒤 확인 화면)은 서버가 재시도를 받아 주는 유예 시간까지 그대로 둔다.
    /// 업로드 중·완료는 제출 응답에 맡긴다.
    @discardableResult
    func expireIfNeeded() -> Bool {
        guard let deadline, serverNow >= deadline else { return false }
        let isLateRetryOver = serverNow >= deadline.addingTimeInterval(VerificationSession.lateRetryGrace)
        switch state {
        case .guide, .capturing:
            break
        case .confirming(let photo), .uploadFailed(let photo):
            guard !photo.hasStartedUpload || isLateRetryOver else { return false }
        case .loading, .loadFailed, .uploading, .submitted, .timedOut:
            return false
        }
        state = .timedOut
        if sheet == .permissionRequired {
            sheet = nil
        }
        return true
    }

    private func apply(_ session: VerificationSession) {
        self.session = session
        clockOffset = session.serverNow.timeIntervalSince(now())
    }

    private func logError(_ message: String, _ error: Error) {
        logger.error("\(message, privacy: .public): \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
