import AVFoundation
import UIKit

enum CameraAuthorization: Equatable {
    case notDetermined
    case authorized
    /// 거부 또는 제한. 앱에서 다시 물을 수 없어 설정 앱으로 안내한다.
    case denied
}

/// 카메라 권한. 테스트·Preview·시뮬레이터에서는 가짜 구현을 넣는다.
protocol CameraPermission {
    var status: CameraAuthorization { get }
    func requestAccess() async -> Bool
}

/// 카메라 화면에 그릴 내용. 실제 카메라는 캡처 세션, 가짜 카메라는 샘플 이미지다.
enum CameraPreviewSource {
    case session(AVCaptureSession)
    case image(UIImage)
}

/// 촬영 중 세션 상태 변화.
enum CameraEvent: Equatable {
    /// 다른 앱·전화·멀티태스킹 등으로 세션이 멈췄다. 끝나면 `interruptionEnded`가 온다.
    case interrupted
    case interruptionEnded
    /// 런타임 오류(미디어 서비스 재설정 포함). 세션이 멈췄으므로 다시 시작해야 한다.
    case runtimeError
}

/// 카메라 촬영. 앨범 사진은 받지 않고 이 서비스로 찍은 사진만 쓴다.
protocol CameraService: AnyObject {
    var previewSource: CameraPreviewSource { get }
    /// 세션 상태 알림. 부를 때마다 새 스트림을 만든다. 시작 전에 만들어 두어야 시작 직후 알림을 놓치지 않는다.
    func events() -> AsyncStream<CameraEvent>
    func start() async throws
    func stop()
    /// 전면·후면 카메라를 바꾼다.
    func switchPosition() async throws
    /// 찍은 사진의 원본 파일 데이터(EXIF 등 메타데이터 포함). 축소·메타데이터 제거는 `VerificationPhotoEncoder`가 한다.
    func capturePhoto() async throws -> Data
}

struct SystemCameraPermission: CameraPermission {
    var status: CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
