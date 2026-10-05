import Foundation
import Observation

/// 이의신청 작성의 `사진 다시 찍기`. 권한을 확인해 촬영 화면이나 권한 안내 시트를 띄우고, 찍은 사진(JPEG)을 돌려준다.
/// 인증 시간과 상관없이 찍을 수 있다(이의신청용 사진은 새 청소 인증으로 제출되지 않는다).
@Observable
@MainActor
final class AppealPhotoCaptureViewModel {
    enum Presentation: Equatable {
        case camera
        /// 카메라 권한이 거부돼 있다. 청소 인증과 같은 `카메라 권한 필요` 시트(317:365)를 띄운다.
        case permissionRequired
    }

    private(set) var presentation: Presentation?
    let capture: CameraCapture

    private let permission: CameraPermission

    init(camera: CameraService, permission: CameraPermission) {
        capture = CameraCapture(camera: camera)
        self.permission = permission
    }

    /// 셔터를 누를 수 있는지.
    var canTakePhoto: Bool {
        presentation == .camera && capture.canTakePhoto
    }

    /// `사진 다시 찍기` 타일. 권한이 없으면 묻고, 거부돼 있으면 설정 안내 시트를 띄운다.
    func open() async {
        guard presentation == nil else { return }
        switch permission.status {
        case .authorized:
            presentation = .camera
        case .notDetermined:
            let isGranted = await permission.requestAccess()
            guard presentation == nil else { return }
            presentation = isGranted ? .camera : .permissionRequired
        case .denied:
            presentation = .permissionRequired
        }
    }

    /// 촬영 화면 닫기, 권한 시트 `나중에`·`설정으로 이동`.
    func dismiss() {
        presentation = nil
    }

    /// 찍은 사진을 돌려주고 촬영 화면을 닫는다. 찍지 못했으면 nil이고 촬영 화면에 남는다(토스트로 알린다).
    func takePhoto() async -> Data? {
        guard canTakePhoto, let output = await capture.takePhoto() else { return nil }
        // 찍는 사이 닫았으면 붙이지 않는다.
        guard presentation == .camera else { return nil }
        presentation = nil
        return output.jpegData
    }
}
