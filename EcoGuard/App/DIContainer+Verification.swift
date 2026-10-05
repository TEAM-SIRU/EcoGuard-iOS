import Foundation

extension DIContainer {
    /// 청소 인증 흐름. 시뮬레이터에는 카메라가 없어 가짜 카메라(샘플 이미지)를 쓴다.
    // TODO: 서버 연동 때 저장소를 DIContainer 프로퍼티로 옮기고 실제 구현으로 바꾼다. 앱 셸(#18) 작업과 충돌을 피하려고 따로 둔다.
    func makeCameraVerificationViewModel(
        repository: VerificationRepository = MockVerificationRepository()
    ) -> CameraVerificationViewModel {
        let (camera, permission) = makeCamera()
        return CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: camera,
            permission: permission
        )
    }

    /// 카메라와 권한. 시뮬레이터에는 카메라가 없어 가짜 카메라(샘플 이미지)와 허용된 권한을 쓴다.
    /// 청소 인증과 이의신청 사진 다시 찍기가 같이 쓴다.
    func makeCamera() -> (CameraService, CameraPermission) {
        #if targetEnvironment(simulator)
        (FakeCameraService(), FakeCameraPermission())
        #else
        (AVCameraService(), SystemCameraPermission())
        #endif
    }
}
