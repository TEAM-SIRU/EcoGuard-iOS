import Foundation
import Testing
import UIKit
@testable import EcoGuard

@MainActor
struct AppealPhotoCaptureViewModelTests {
    private func makeViewModel(
        permission: FakeCameraPermission? = nil,
        camera: FakeCameraService? = nil
    ) -> (AppealPhotoCaptureViewModel, FakeCameraService) {
        let camera = camera ?? FakeCameraService(sampleImage: FakeCameraService.makeSampleImage(size: CGSize(width: 30, height: 40)))
        return (AppealPhotoCaptureViewModel(camera: camera, permission: permission ?? FakeCameraPermission()), camera)
    }

    /// 촬영 화면에서 카메라를 켜고 준비될 때까지 기다린다. 끝나면 `capture.stop()`으로 멈춘다.
    private func startCamera(_ viewModel: AppealPhotoCaptureViewModel) async -> Task<Void, Never> {
        let task = Task { await viewModel.capture.run() }
        await waitUntil { viewModel.capture.isCameraReady || viewModel.capture.isCameraUnavailable }
        return task
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }

    // MARK: - 권한

    @Test func authorizedOpensCamera() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.open()

        #expect(viewModel.presentation == .camera)
    }

    @Test func notDeterminedAsksThenOpensCameraWhenGranted() async {
        let permission = FakeCameraPermission(status: .notDetermined, grantsOnRequest: true)
        let (viewModel, _) = makeViewModel(permission: permission)

        await viewModel.open()

        #expect(permission.requestCount == 1)
        #expect(viewModel.presentation == .camera)
    }

    @Test func notDeterminedRefusedShowsPermissionSheet() async {
        let permission = FakeCameraPermission(status: .notDetermined, grantsOnRequest: false)
        let (viewModel, _) = makeViewModel(permission: permission)

        await viewModel.open()

        #expect(viewModel.presentation == .permissionRequired)
    }

    @Test func deniedShowsPermissionSheetWithoutAsking() async {
        let permission = FakeCameraPermission(status: .denied)
        let (viewModel, _) = makeViewModel(permission: permission)

        await viewModel.open()

        #expect(permission.requestCount == 0)
        #expect(viewModel.presentation == .permissionRequired)
    }

    @Test func dismissingPermissionSheetReturnsToForm() async {
        let (viewModel, _) = makeViewModel(permission: FakeCameraPermission(status: .denied))
        await viewModel.open()

        viewModel.dismiss()

        #expect(viewModel.presentation == nil)
    }

    // MARK: - 촬영

    @Test func shutterIsDisabledUntilCameraStarts() async {
        let (viewModel, camera) = makeViewModel()
        await viewModel.open()

        #expect(viewModel.canTakePhoto == false)
        #expect(await viewModel.takePhoto() == nil)
        #expect(camera.captureCount == 0)
    }

    @Test func takingPhotoReturnsJPEGAndClosesCamera() async throws {
        let (viewModel, camera) = makeViewModel()
        await viewModel.open()
        let cameraTask = await startCamera(viewModel)

        let jpegData = try #require(await viewModel.takePhoto())
        viewModel.capture.stop()
        await cameraTask.value

        #expect(UIImage(data: jpegData) != nil)
        #expect(camera.captureCount == 1)
        #expect(viewModel.presentation == nil)
    }

    @Test func captureFailureStaysOnCameraAndCountsFailure() async {
        let camera = FakeCameraService(sampleImage: FakeCameraService.makeSampleImage(size: CGSize(width: 30, height: 40)))
        camera.shouldFailCapture = true
        let (viewModel, _) = makeViewModel(camera: camera)
        await viewModel.open()
        let cameraTask = await startCamera(viewModel)

        let jpegData = await viewModel.takePhoto()
        viewModel.capture.stop()
        await cameraTask.value

        #expect(jpegData == nil)
        #expect(viewModel.presentation == .camera)
        #expect(viewModel.capture.captureFailureCount == 1)
    }

    @Test func closingCameraBeforeOpeningAgainStartsOver() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.open()

        viewModel.dismiss()
        await viewModel.open()

        #expect(viewModel.presentation == .camera)
    }

    @Test func photoTakenWithFullAttachmentsIsNotAdded() async throws {
        let (capture, _) = makeViewModel()
        let form = AppealFormViewModel(
            target: MockAppealRepository.Fixture.target,
            submitAppealUseCase: SubmitAppealUseCase(appealRepository: MockAppealRepository(delay: .zero))
        )
        for index in 0..<AppealMessage.maxPhotoCount {
            form.addPhoto(Data([UInt8(index)]))
        }
        let attached = form.photos
        await capture.open()
        let cameraTask = await startCamera(capture)

        let jpegData = try #require(await capture.takePhoto())
        form.addPhoto(jpegData)
        capture.capture.stop()
        await cameraTask.value

        #expect(form.canAddPhoto == false)
        #expect(form.photos == attached)
    }

    @Test func takenPhotoIsAddedToAppealForm() async throws {
        let (capture, _) = makeViewModel()
        let repository = MockAppealRepository(delay: .zero)
        let form = AppealFormViewModel(
            target: MockAppealRepository.Fixture.target,
            submitAppealUseCase: SubmitAppealUseCase(appealRepository: repository)
        )
        await capture.open()
        let cameraTask = await startCamera(capture)

        let jpegData = try #require(await capture.takePhoto())
        form.addPhoto(jpegData)
        capture.capture.stop()
        await cameraTask.value

        #expect(form.photos.map(\.jpegData) == [jpegData])
    }
}
