import Foundation
import Observation
import os

/// 촬영 화면이 보이는 동안의 카메라 세션 상태와 셔터·전환. 청소 인증 촬영과 이의신청 사진 다시 찍기가 같이 쓴다.
/// 언제 찍을 수 있는지(인증 마감 등)는 쓰는 쪽 ViewModel이 더 막는다.
@Observable
@MainActor
final class CameraCapture {
    let camera: CameraService

    private(set) var isTakingPhoto = false
    private(set) var isSwitchingCamera = false
    /// 카메라 세션이 돌고 있어 찍을 수 있는지. 시작 성공 후 true, 중단·오류 시 false.
    private(set) var isCameraReady = false
    /// 세션 중단·시작 실패로 카메라를 쓸 수 없다. 화면에 안내를 겹친다.
    private(set) var isCameraUnavailable = false
    /// 촬영·변환에 실패한 횟수. 바뀔 때마다 화면이 토스트와 VoiceOver 안내를 띄운다.
    private(set) var captureFailureCount = 0

    private let logger = Logger(subsystem: "EcoGuard", category: "Camera")

    init(camera: CameraService) {
        self.camera = camera
    }

    var canTakePhoto: Bool {
        isCameraReady && !isTakingPhoto && !isSwitchingCamera
    }

    var canSwitchCamera: Bool {
        isCameraReady && !isTakingPhoto && !isSwitchingCamera
    }

    /// 촬영 화면이 보이는 동안 카메라를 켜 두고 세션 중단·오류에 맞춰 셔터를 막거나 다시 연다.
    /// 화면이 사라져 작업이 취소되면 끝난다.
    func run() async {
        let events = camera.events()
        await startSession()
        for await event in events {
            switch event {
            case .interrupted:
                isCameraReady = false
                isCameraUnavailable = true
            case .interruptionEnded:
                isCameraReady = true
                isCameraUnavailable = false
            case .runtimeError:
                // 미디어 서비스 재설정 등으로 세션이 멈췄다. 다시 시작해 본다.
                isCameraReady = false
                isCameraUnavailable = true
                await startSession()
            }
        }
    }

    func stop() {
        camera.stop()
        isCameraReady = false
    }

    /// 찍어서 업로드용으로 줄인 사진. 찍을 수 없거나 실패했으면 nil이고, 실패는 `captureFailureCount`를 올린다.
    func takePhoto() async -> VerificationPhotoEncoder.Output? {
        guard canTakePhoto else { return nil }
        isTakingPhoto = true
        defer { isTakingPhoto = false }
        do {
            let data = try await camera.capturePhoto()
            guard let output = await VerificationPhotoEncoder.encodeInBackground(data) else {
                logger.error("사진 변환 실패")
                captureFailureCount += 1
                return nil
            }
            return output
        } catch is CancellationError {
            return nil
        } catch {
            logError("촬영 실패", error)
            captureFailureCount += 1
            return nil
        }
    }

    func switchCamera() async {
        guard canSwitchCamera else { return }
        isSwitchingCamera = true
        defer { isSwitchingCamera = false }
        do {
            try await camera.switchPosition()
        } catch {
            logError("카메라 전환 실패", error)
        }
    }

    private func startSession() async {
        do {
            try await camera.start()
            isCameraReady = true
            isCameraUnavailable = false
        } catch {
            logError("카메라 시작 실패", error)
            isCameraReady = false
            isCameraUnavailable = true
        }
    }

    private func logError(_ message: String, _ error: Error) {
        logger.error("\(message, privacy: .public): \(String(describing: type(of: error)), privacy: .public) \(String(describing: error), privacy: .private)")
    }
}
