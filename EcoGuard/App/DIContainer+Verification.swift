import Foundation

extension DIContainer {
    /// 청소 인증 흐름. 시뮬레이터에는 카메라가 없어 가짜 카메라(샘플 이미지)를 쓴다.
    /// 서버에 오늘 인증 정보 API가 없어 실제 저장소도 인증 정보는 Mock에서 가져온다.
    func makeCameraVerificationViewModel(
        repository: VerificationRepository? = nil
    ) -> CameraVerificationViewModel {
        let repository = repository ?? apiClient.map {
            VerificationRepositoryImpl(apiClient: $0, sessionSource: MockVerificationRepository())
        } ?? MockVerificationRepository()
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
