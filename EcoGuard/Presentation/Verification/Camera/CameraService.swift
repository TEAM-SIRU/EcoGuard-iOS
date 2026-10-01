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

/// 카메라 촬영. 앨범 사진은 받지 않고 이 서비스로 찍은 사진만 쓴다.
protocol CameraService: AnyObject {
    var previewSource: CameraPreviewSource { get }
    func start() async throws
    func stop()
    /// 전면·후면 카메라를 바꾼다.
    func switchPosition() async throws
    func capturePhoto() async throws -> UIImage
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
