import Foundation
import Testing
import UIKit
@testable import EcoGuard

private final class TestClock {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
struct CameraVerificationViewModelTests {
    private let clock = TestClock(now: Date(timeIntervalSinceReferenceDate: 0))
    /// Mock 기본 마감: 지금부터 5분 32초 뒤.
    private var deadline: Date {
        Date(timeIntervalSinceReferenceDate: MockVerificationRepository.Fixture.remainingUntilDeadline)
    }

    private func makeViewModel(
        scenario: MockVerificationRepository.Scenario = .open,
        uploadResults: [MockVerificationRepository.UploadResult] = [.success],
        permission: FakeCameraPermission = FakeCameraPermission(),
        camera: FakeCameraService = FakeCameraService(sampleImage: FakeCameraService.makeSampleImage(size: CGSize(width: 30, height: 40)))
    ) -> (CameraVerificationViewModel, MockVerificationRepository) {
        let clock = clock
        let repository = MockVerificationRepository(
            scenario: scenario,
            uploadResults: uploadResults,
            delay: .zero,
            now: { clock.now }
        )
        let viewModel = CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: camera,
            permission: permission,
            now: { clock.now }
        )
        return (viewModel, repository)
    }

    /// 안내 → 촬영 → 확인까지 진행한 사진.
    private func capturedPhoto(_ viewModel: CameraVerificationViewModel) async -> CameraVerificationViewModel.CapturedPhoto? {
        await viewModel.load()
        await viewModel.startCapture()
        await viewModel.takePhoto()
        guard case .confirming(let photo) = viewModel.state else { return nil }
        return photo
    }

    // MARK: - 진입

    @Test func openSessionShowsGuideWithDeadline() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()

        #expect(viewModel.state == .guide)
        #expect(viewModel.sheet == nil)
        #expect(viewModel.deadline == deadline)
        #expect(viewModel.session?.area == "본관 2층 복도 A")
    }

    @Test func outsideWindowShowsSheetThatClosesFlow() async {
        let (viewModel, _) = makeViewModel(scenario: .outsideWindow)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.sheet == .outsideWindow)
        #expect(viewModel.sheet?.closesFlow == true)
        #expect(viewModel.state == .guide)
    }

    @Test func alreadySubmittedShowsSheetAndBlocksCapture() async {
        let (viewModel, _) = makeViewModel(scenario: .alreadySubmitted)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.sheet == .alreadySubmitted(submittedAt: MockVerificationRepository.Fixture.submittedAt))
        #expect(viewModel.state == .guide)
    }

    @Test func fetchFailureShowsLoadFailed() async {
        let (viewModel, _) = makeViewModel(scenario: .failure)

        await viewModel.load()

        #expect(viewModel.state == .loadFailed)
    }

    // MARK: - 권한

    @Test func deniedPermissionShowsSettingsSheetAndStaysOnGuide() async {
        let permission = FakeCameraPermission(status: .denied)
        let (viewModel, _) = makeViewModel(permission: permission)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.sheet == .permissionRequired)
        #expect(viewModel.sheet?.closesFlow == false)
        #expect(viewModel.state == .guide)
        #expect(permission.requestCount == 0)

        viewModel.dismissSheet()
        #expect(viewModel.sheet == nil)
    }

    @Test func undeterminedPermissionAsksThenCaptures() async {
        let permission = FakeCameraPermission(status: .notDetermined, grantsOnRequest: true)
        let (viewModel, _) = makeViewModel(permission: permission)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(permission.requestCount == 1)
        #expect(viewModel.state == .capturing)
    }

    @Test func undeterminedPermissionRefusedShowsSettingsSheet() async {
        let permission = FakeCameraPermission(status: .notDetermined, grantsOnRequest: false)
        let (viewModel, _) = makeViewModel(permission: permission)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.sheet == .permissionRequired)
        #expect(viewModel.state == .guide)
    }

    // MARK: - 촬영 → 확인 → 재촬영 → 제출

    @Test func captureConfirmRetakeAndSubmitSucceeds() async throws {
        let camera = FakeCameraService(sampleImage: FakeCameraService.makeSampleImage(size: CGSize(width: 30, height: 40)))
        let (viewModel, repository) = makeViewModel(camera: camera)

        let first = try #require(await capturedPhoto(viewModel))
        viewModel.retake()
        #expect(viewModel.state == .capturing)

        await viewModel.takePhoto()
        guard case .confirming(let second) = viewModel.state else {
            Issue.record("확인 화면이 아님: \(viewModel.state)")
            return
        }
        #expect(second.photo.id != first.photo.id)
        #expect(camera.captureCount == 2)

        clock.now = Date(timeIntervalSinceReferenceDate: 244)
        await viewModel.submit()

        #expect(viewModel.state == .submitted(second, submittedAt: Date(timeIntervalSinceReferenceDate: 244)))
        #expect(repository.submittedPhotoIDs == [second.photo.id])
    }

    @Test func cancelCaptureReturnsToGuide() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        await viewModel.startCapture()
        viewModel.cancelCapture()

        #expect(viewModel.state == .guide)
    }

    @Test func captureFailureStaysOnCapturing() async {
        let camera = FakeCameraService(sampleImage: FakeCameraService.makeSampleImage(size: CGSize(width: 30, height: 40)))
        camera.shouldFailCapture = true
        let (viewModel, _) = makeViewModel(camera: camera)

        await viewModel.load()
        await viewModel.startCapture()
        await viewModel.takePhoto()

        #expect(viewModel.state == .capturing)
        #expect(viewModel.isTakingPhoto == false)
    }

    @Test func uploadFailureThenRetrySamePhotoSucceeds() async throws {
        let (viewModel, repository) = makeViewModel(uploadResults: [.networkFailure, .success])
        let photo = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        #expect(viewModel.state == .uploadFailed(photo))

        await viewModel.submit()
        guard case .submitted(let submitted, _) = viewModel.state else {
            Issue.record("제출 완료가 아님: \(viewModel.state)")
            return
        }
        #expect(submitted == photo)
        #expect(repository.submittedPhotoIDs == [photo.photo.id, photo.photo.id])
    }

    @Test func retryAfterDeadlineWithSamePhotoIsAccepted() async throws {
        let (viewModel, _) = makeViewModel(uploadResults: [.networkFailure, .success])
        let photo = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        clock.now = deadline.addingTimeInterval(60)
        viewModel.expireIfNeeded()
        #expect(viewModel.state == .uploadFailed(photo))

        await viewModel.submit()
        guard case .submitted = viewModel.state else {
            Issue.record("마감 전에 시작한 사진의 재시도가 거부됨: \(viewModel.state)")
            return
        }
    }

    // MARK: - 마감

    @Test func deadlineDuringCaptureTimesOut() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        await viewModel.startCapture()
        clock.now = deadline
        let expired = viewModel.expireIfNeeded()

        #expect(expired)
        #expect(viewModel.state == .timedOut)
    }

    @Test func deadlineOnConfirmTimesOutAndRetakeIsBlocked() async throws {
        let (viewModel, _) = makeViewModel()
        _ = try #require(await capturedPhoto(viewModel))

        clock.now = deadline
        viewModel.retake()

        #expect(viewModel.state == .timedOut)
    }

    @Test func submitNewPhotoAfterDeadlineTimesOut() async throws {
        let (viewModel, _) = makeViewModel()
        _ = try #require(await capturedPhoto(viewModel))

        // 화면이 마감 시각 갱신을 놓친 채 보내기를 누른 경우. 서버가 거절한다.
        clock.now = deadline.addingTimeInterval(1)
        await viewModel.submit()

        #expect(viewModel.state == .timedOut)
    }

    @Test func startCaptureAfterDeadlineTimesOut() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        clock.now = deadline
        await viewModel.startCapture()

        #expect(viewModel.state == .timedOut)
    }

    @Test func checkUploadStatusShowsAlreadySubmittedWhenServerHasPhoto() async throws {
        let (viewModel, repository) = makeViewModel(uploadResults: [.success])
        _ = try #require(await capturedPhoto(viewModel))
        await viewModel.submit()
        // 응답 전에 마감 화면으로 넘어간 경우를 흉내 낸다.
        let timedOut = CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: FakeCameraService(),
            permission: FakeCameraPermission(),
            state: .timedOut
        )

        await timedOut.checkUploadStatus()

        #expect(timedOut.sheet == .alreadySubmitted(submittedAt: Date(timeIntervalSinceReferenceDate: 0)))
    }

    @Test func checkUploadStatusKeepsTimedOutWhenNothingSubmitted() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()
        clock.now = deadline
        viewModel.expireIfNeeded()

        await viewModel.checkUploadStatus()

        #expect(viewModel.state == .timedOut)
        #expect(viewModel.sheet == nil)
    }
}

struct VerificationPhotoEncoderTests {
    @Test func shrinksLongSideToLimit() throws {
        let image = FakeCameraService.makeSampleImage(size: CGSize(width: 3024, height: 4032))

        let output = try #require(VerificationPhotoEncoder.encode(image))

        #expect(output.image.size == CGSize(width: 1200, height: 1600))
        #expect(UIImage(data: output.jpegData) != nil)
    }

    @Test func keepsSmallImageSize() throws {
        let image = FakeCameraService.makeSampleImage(size: CGSize(width: 300, height: 400))

        let output = try #require(VerificationPhotoEncoder.encode(image))

        #expect(output.image.size == CGSize(width: 300, height: 400))
    }
}
