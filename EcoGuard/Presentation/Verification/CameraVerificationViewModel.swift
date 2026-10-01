import Foundation
import Observation
import os
import UIKit

/// 청소 인증 흐름: 촬영 안내 → 촬영 → 확인 → 제출.
/// 인증 가능 여부·마감은 서버 값으로 판단하고, 클라이언트 시간은 마감 도달 시 화면 전환에만 쓴다.
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
        case outsideWindow
        case alreadySubmitted(submittedAt: Date)
        case permissionRequired

        /// 확인하면 인증 흐름을 닫는 시트. 권한 안내는 닫아도 촬영 안내에 머문다.
        var closesFlow: Bool {
            self != .permissionRequired
        }
    }

    /// 찍은 사진. 업로드용 JPEG와 화면 표시용 이미지를 함께 둔다.
    struct CapturedPhoto: Equatable {
        let photo: VerificationPhoto
        let image: UIImage

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.photo == rhs.photo
        }
    }

    private(set) var state: State
    private(set) var sheet: Sheet?
    private(set) var session: VerificationSession?
    private(set) var isTakingPhoto = false

    let camera: CameraService

    private let fetchSessionUseCase: FetchVerificationSessionUseCase
    private let submitPhotoUseCase: SubmitVerificationPhotoUseCase
    private let permission: CameraPermission
    private let now: () -> Date
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
        self.camera = camera
        self.permission = permission
        self.now = now
        self.state = state
        self.sheet = sheet
        self.session = session
    }

    /// 서버가 정한 마감 시각. 인증 가능할 때만 있다.
    var deadline: Date? {
        guard case .open(let deadline) = session?.availability else { return nil }
        return deadline
    }

    func load() async {
        state = .loading
        do {
            let session = try await fetchSessionUseCase.execute()
            self.session = session
            state = .guide
            switch session.availability {
            case .open:
                sheet = nil
                expireIfNeeded()
            case .outsideWindow:
                sheet = .outsideWindow
            case .alreadySubmitted(let submittedAt):
                sheet = .alreadySubmitted(submittedAt: submittedAt)
            }
        } catch is CancellationError {
            return
        } catch {
            logError("인증 정보 조회 실패", error)
            state = .loadFailed
        }
    }

    /// 촬영 안내의 `촬영하기`. 권한이 없으면 묻고, 거부돼 있으면 설정 안내 시트를 띄운다.
    func startCapture() async {
        guard state == .guide, deadline != nil else { return }
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
        guard state == .capturing, !isTakingPhoto else { return }
        isTakingPhoto = true
        defer { isTakingPhoto = false }
        do {
            let image = try await camera.capturePhoto()
            guard state == .capturing else { return }
            guard let output = VerificationPhotoEncoder.encode(image) else {
                logger.error("인증 사진 JPEG 변환 실패")
                return
            }
            let photo = VerificationPhoto(id: UUID(), jpegData: output.jpegData, capturedAt: now())
            state = .confirming(CapturedPhoto(photo: photo, image: output.image))
        } catch is CancellationError {
            return
        } catch {
            logError("촬영 실패", error)
        }
    }

    func switchCamera() async {
        do {
            try await camera.switchPosition()
        } catch {
            logError("카메라 전환 실패", error)
        }
    }

    /// 확인 화면의 `다시 찍기`·뒤로가기. 새 사진이므로 마감이 지났으면 시간 초과로 보낸다.
    func retake() {
        guard case .confirming = state else { return }
        guard !expireIfNeeded() else { return }
        state = .capturing
    }

    /// 확인 화면의 `보내기`, 업로드 실패 화면의 `같은 사진 다시 보내기`.
    /// 같은 사진은 같은 `photo.id`로 보내 마감 전에 시작한 업로드를 마감 후에도 이어 갈 수 있게 한다.
    func submit() async {
        let captured: CapturedPhoto
        switch state {
        case .confirming(let photo), .uploadFailed(let photo):
            captured = photo
        default:
            return
        }
        let previous = state
        state = .uploading(captured)
        do {
            let submission = try await submitPhotoUseCase.execute(captured.photo)
            state = .submitted(captured, submittedAt: submission.submittedAt)
        } catch is CancellationError {
            state = previous
        } catch VerificationError.deadlinePassed {
            state = .timedOut
        } catch VerificationError.alreadySubmitted(let submittedAt) {
            state = .uploadFailed(captured)
            sheet = .alreadySubmitted(submittedAt: submittedAt)
        } catch {
            logError("인증 사진 업로드 실패", error)
            state = .uploadFailed(captured)
        }
    }

    /// 시간 초과 화면의 `업로드 상태 확인`. 서버에 제출된 사진이 있으면 이미 제출 시트를 띄운다.
    func checkUploadStatus() async {
        guard state == .timedOut else { return }
        do {
            let session = try await fetchSessionUseCase.execute()
            self.session = session
            if case .alreadySubmitted(let submittedAt) = session.availability {
                sheet = .alreadySubmitted(submittedAt: submittedAt)
            }
        } catch is CancellationError {
            return
        } catch {
            logError("업로드 상태 조회 실패", error)
        }
    }

    func dismissSheet() {
        sheet = nil
    }

    /// 마감이 지났고 아직 업로드를 시작하지 않았으면 시간 초과로 바꾼다. 바꿨으면 true.
    /// 화면이 마감 시각에 부른다. 업로드 중·실패·완료 상태는 마감 전에 시작한 제출이므로 그대로 둔다.
    @discardableResult
    func expireIfNeeded() -> Bool {
        guard let deadline, now() >= deadline else { return false }
        switch state {
        case .guide, .capturing, .confirming:
            state = .timedOut
            if sheet == .permissionRequired {
                sheet = nil
            }
            return true
        case .loading, .loadFailed, .uploading, .uploadFailed, .submitted, .timedOut:
            return false
        }
    }

    private func logError(_ message: String, _ error: Error) {
        logger.error("\(message, privacy: .public): \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
