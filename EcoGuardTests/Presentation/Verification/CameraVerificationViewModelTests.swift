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
    /// 서버 시계. Mock 저장소가 쓴다.
    private let serverClock = TestClock(now: Date(timeIntervalSinceReferenceDate: 0))
    /// 서버보다 빠르거나 느린 기기 시계 차이(초).
    private var deviceSkew: TimeInterval = 0
    /// Mock 기본 마감: 서버 시각 기준 지금부터 5분 32초 뒤.
    private let deadline = Date(timeIntervalSinceReferenceDate: MockVerificationRepository.Fixture.remainingUntilDeadline)

    private func makeViewModel(
        scenario: MockVerificationRepository.Scenario = .open,
        uploadResults: [MockVerificationRepository.UploadResult] = [.success],
        permission: FakeCameraPermission? = nil,
        camera: FakeCameraService? = nil
    ) -> (CameraVerificationViewModel, MockVerificationRepository) {
        let serverClock = serverClock
        let deviceSkew = deviceSkew
        let repository = MockVerificationRepository(
            scenario: scenario,
            uploadResults: uploadResults,
            delay: .zero,
            now: { serverClock.now }
        )
        let viewModel = CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: camera ?? Self.makeCamera(),
            permission: permission ?? FakeCameraPermission(),
            now: { serverClock.now.addingTimeInterval(deviceSkew) }
        )
        return (viewModel, repository)
    }

    private static func makeCamera() -> FakeCameraService {
        FakeCameraService(sampleImage: FakeCameraService.makeSampleImage(size: CGSize(width: 30, height: 40)))
    }

    /// 촬영 화면에서 카메라를 켜고 준비될 때까지 기다린다. 끝나면 `capture.stop()`으로 멈춘다.
    private func startCamera(_ viewModel: CameraVerificationViewModel) async -> Task<Void, Never> {
        let task = Task { await viewModel.capture.run() }
        await waitUntil { viewModel.isCameraReady || viewModel.isCameraUnavailable }
        return task
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }

    /// 안내 → 촬영 → 확인까지 진행한 사진.
    private func capturedPhoto(_ viewModel: CameraVerificationViewModel) async -> CameraVerificationViewModel.CapturedPhoto? {
        await viewModel.load()
        await viewModel.startCapture()
        let cameraTask = await startCamera(viewModel)
        await viewModel.takePhoto()
        viewModel.capture.stop()
        await cameraTask.value
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

        #expect(viewModel.sheet == .outsideWindow(.outsideHours))
        #expect(viewModel.sheet?.closesFlow == true)
        #expect(viewModel.state == .guide)
    }

    /// 주말·방학은 `인증 시간 아님` 시트에 사유만 바꿔 띄운다.
    @Test(arguments: [
        (MockVerificationRepository.Scenario.weekend, VerificationClosedReason.weekend),
        (.vacation, .vacation)
    ])
    func closedDayShowsOutsideWindowSheetWithReason(scenario: MockVerificationRepository.Scenario, reason: VerificationClosedReason) async {
        let (viewModel, _) = makeViewModel(scenario: scenario)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.sheet == .outsideWindow(reason))
        #expect(viewModel.sheet?.closesFlow == true)
        #expect(viewModel.state == .guide)
    }

    @Test func alreadySubmittedShowsSheetAndBlocksCapture() async {
        let (viewModel, _) = makeViewModel(scenario: .alreadySubmitted)

        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.sheet == .alreadySubmitted(submittedAt: MockVerificationRepository.Fixture.submittedAt, status: .processing))
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

    // MARK: - 카메라 준비 상태

    @Test func shutterIsDisabledUntilCameraStarts() async {
        let camera = Self.makeCamera()
        let (viewModel, _) = makeViewModel(camera: camera)
        await viewModel.load()
        await viewModel.startCapture()

        #expect(viewModel.canTakePhoto == false)
        await viewModel.takePhoto()
        #expect(camera.captureCount == 0)

        let cameraTask = await startCamera(viewModel)
        #expect(viewModel.isCameraReady)
        #expect(viewModel.canTakePhoto)
        #expect(viewModel.canSwitchCamera)

        viewModel.capture.stop()
        await cameraTask.value
        #expect(viewModel.isCameraReady == false)
    }

    @Test func cameraStartFailureShowsUnavailable() async {
        let camera = Self.makeCamera()
        camera.shouldFailStart = true
        let (viewModel, _) = makeViewModel(camera: camera)
        await viewModel.load()
        await viewModel.startCapture()

        let cameraTask = await startCamera(viewModel)

        #expect(viewModel.isCameraUnavailable)
        #expect(viewModel.canTakePhoto == false)
        viewModel.capture.stop()
        await cameraTask.value
    }

    @Test func interruptionDisablesShutterUntilItEnds() async {
        let camera = Self.makeCamera()
        let (viewModel, _) = makeViewModel(camera: camera)
        await viewModel.load()
        await viewModel.startCapture()
        let cameraTask = await startCamera(viewModel)

        camera.send(.interrupted)
        await waitUntil { !viewModel.isCameraReady }
        #expect(viewModel.isCameraUnavailable)
        #expect(viewModel.canTakePhoto == false)

        camera.send(.interruptionEnded)
        await waitUntil { viewModel.isCameraReady }
        #expect(viewModel.isCameraUnavailable == false)
        #expect(viewModel.canTakePhoto)

        viewModel.capture.stop()
        await cameraTask.value
    }

    @Test func runtimeErrorRestartsSession() async {
        let camera = Self.makeCamera()
        let (viewModel, _) = makeViewModel(camera: camera)
        await viewModel.load()
        await viewModel.startCapture()
        let cameraTask = await startCamera(viewModel)
        #expect(camera.startCount == 1)

        camera.send(.runtimeError)
        await waitUntil { camera.startCount == 2 && viewModel.isCameraReady }

        #expect(camera.startCount == 2)
        #expect(viewModel.isCameraReady)
        #expect(viewModel.isCameraUnavailable == false)
        viewModel.capture.stop()
        await cameraTask.value
    }

    // MARK: - 촬영 → 확인 → 재촬영 → 제출

    @Test func captureConfirmRetakeAndSubmitSucceeds() async throws {
        let camera = Self.makeCamera()
        let (viewModel, repository) = makeViewModel(camera: camera)

        let first = try #require(await capturedPhoto(viewModel))
        viewModel.retake()
        #expect(viewModel.state == .capturing)

        let cameraTask = await startCamera(viewModel)
        await viewModel.takePhoto()
        viewModel.capture.stop()
        await cameraTask.value
        guard case .confirming(let second) = viewModel.state else {
            Issue.record("확인 화면이 아님: \(viewModel.state)")
            return
        }
        #expect(second.photo.id != first.photo.id)
        #expect(camera.captureCount == 2)

        serverClock.now = Date(timeIntervalSinceReferenceDate: 244)
        await viewModel.submit()

        guard case .submitted(let submitted, let submittedAt) = viewModel.state else {
            Issue.record("제출 완료가 아님: \(viewModel.state)")
            return
        }
        #expect(submitted.photo.id == second.photo.id)
        #expect(submittedAt == Date(timeIntervalSinceReferenceDate: 244))
        #expect(repository.submittedPhotoIDs == [second.photo.id])
    }

    @Test func cancelCaptureReturnsToGuide() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        await viewModel.startCapture()
        viewModel.cancelCapture()

        #expect(viewModel.state == .guide)
    }

    @Test func captureFailureStaysOnCapturingAndCountsFailure() async {
        let camera = Self.makeCamera()
        camera.shouldFailCapture = true
        let (viewModel, _) = makeViewModel(camera: camera)

        let photo = await capturedPhoto(viewModel)

        #expect(photo == nil)
        #expect(viewModel.state == .capturing)
        #expect(viewModel.isTakingPhoto == false)
        #expect(viewModel.captureFailureCount == 1)
    }

    /// 실패 → 성공 → `다시 찍기`로 촬영 화면에 다시 들어오면 이전 실패를 안내하지 않는다.
    @Test func reenteringCaptureAfterFailureStartsFailureCountOver() async {
        let camera = Self.makeCamera()
        camera.shouldFailCapture = true
        let (viewModel, _) = makeViewModel(camera: camera)
        #expect(await capturedPhoto(viewModel) == nil)
        #expect(viewModel.captureFailureCount == 1)

        camera.shouldFailCapture = false
        var cameraTask = await startCamera(viewModel)
        await viewModel.takePhoto()
        viewModel.capture.stop()
        await cameraTask.value
        viewModel.retake()
        cameraTask = await startCamera(viewModel)

        #expect(viewModel.state == .capturing)
        #expect(viewModel.captureFailureCount == 0)
        viewModel.capture.stop()
        await cameraTask.value
    }

    @Test func undecodablePhotoCountsFailure() async {
        let camera = Self.makeCamera()
        camera.capturedDataOverride = Data("not an image".utf8)
        let (viewModel, _) = makeViewModel(camera: camera)

        let photo = await capturedPhoto(viewModel)

        #expect(photo == nil)
        #expect(viewModel.state == .capturing)
        #expect(viewModel.captureFailureCount == 1)
    }

    @Test func uploadFailureThenRetrySamePhotoSucceeds() async throws {
        let (viewModel, repository) = makeViewModel(uploadResults: [.networkFailure, .success])
        let photo = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        guard case .uploadFailed(let failed) = viewModel.state else {
            Issue.record("업로드 실패가 아님: \(viewModel.state)")
            return
        }
        #expect(failed.photo.id == photo.photo.id)
        #expect(failed.hasStartedUpload)

        await viewModel.submit()
        guard case .submitted(let submitted, _) = viewModel.state else {
            Issue.record("제출 완료가 아님: \(viewModel.state)")
            return
        }
        #expect(submitted.photo.id == photo.photo.id)
        #expect(repository.submittedPhotoIDs == [photo.photo.id, photo.photo.id])
    }

    /// 처음 보내기 시작한 시각(서버 기준)을 사진에 남기고, 재시도에도 그대로 보낸다.
    @Test func uploadStartedAtIsFirstSendTimeAndKeptOnRetry() async throws {
        var tests = self
        tests.deviceSkew = 180
        let (viewModel, _) = tests.makeViewModel(uploadResults: [.networkFailure, .success])
        let photo = try #require(await tests.capturedPhoto(viewModel))
        #expect(photo.photo.uploadStartedAt == nil)

        serverClock.now = Date(timeIntervalSinceReferenceDate: 100)
        await viewModel.submit()
        guard case .uploadFailed(let failed) = viewModel.state else {
            Issue.record("업로드 실패가 아님: \(viewModel.state)")
            return
        }
        #expect(failed.photo.uploadStartedAt == Date(timeIntervalSinceReferenceDate: 100))

        serverClock.now = Date(timeIntervalSinceReferenceDate: 200)
        await viewModel.submit()
        guard case .submitted(let submitted, _) = viewModel.state else {
            Issue.record("제출 완료가 아님: \(viewModel.state)")
            return
        }
        #expect(submitted.photo.uploadStartedAt == Date(timeIntervalSinceReferenceDate: 100))
    }

    @Test func backFromUploadFailureReturnsToConfirmWithSamePhoto() async throws {
        let (viewModel, _) = makeViewModel(uploadResults: [.networkFailure])
        let photo = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        viewModel.returnToConfirm()

        guard case .confirming(let confirming) = viewModel.state else {
            Issue.record("확인 화면이 아님: \(viewModel.state)")
            return
        }
        #expect(confirming.photo.id == photo.photo.id)
        #expect(confirming.hasStartedUpload)
    }

    @Test func retryAfterDeadlineWithSamePhotoIsAccepted() async throws {
        let (viewModel, _) = makeViewModel(uploadResults: [.networkFailure, .success])
        _ = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        serverClock.now = deadline.addingTimeInterval(60)
        viewModel.expireIfNeeded()
        guard case .uploadFailed = viewModel.state else {
            Issue.record("업로드 실패 화면이 유지되지 않음: \(viewModel.state)")
            return
        }

        await viewModel.submit()
        guard case .submitted = viewModel.state else {
            Issue.record("마감 전에 시작한 사진의 재시도가 거부됨: \(viewModel.state)")
            return
        }
    }

    /// 업로드 실패 → 뒤로(확인 화면) → 마감 → 앱 복귀(scenePhase active에서 expireIfNeeded) → 같은 사진 재시도.
    @Test func startedUploadSurvivesDeadlineAfterGoingBackToConfirm() async throws {
        let (viewModel, _) = makeViewModel(uploadResults: [.networkFailure, .success])
        _ = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        viewModel.returnToConfirm()
        serverClock.now = deadline.addingTimeInterval(30)
        let expired = viewModel.expireIfNeeded()

        #expect(expired == false)
        guard case .confirming = viewModel.state else {
            Issue.record("확인 화면이 유지되지 않음: \(viewModel.state)")
            return
        }
        await viewModel.submit()
        guard case .submitted = viewModel.state else {
            Issue.record("마감 전에 시작한 사진의 재시도가 거부됨: \(viewModel.state)")
            return
        }
    }

    /// 서버는 마감 후 유예 시간(5분)까지만 재시도를 받는다. 앱도 그때 시간 초과로 바꾼다.
    @Test(arguments: [false, true])
    func startedUploadTimesOutWhenLateRetryGraceEnds(backToConfirm: Bool) async throws {
        let (viewModel, _) = makeViewModel(uploadResults: [.networkFailure])
        _ = try #require(await capturedPhoto(viewModel))
        await viewModel.submit()
        if backToConfirm {
            viewModel.returnToConfirm()
        }

        serverClock.now = deadline.addingTimeInterval(VerificationSession.lateRetryGrace - 1)
        #expect(viewModel.expireIfNeeded() == false)
        #expect(viewModel.state != .timedOut)

        serverClock.now = deadline.addingTimeInterval(VerificationSession.lateRetryGrace)
        #expect(viewModel.expireIfNeeded())
        #expect(viewModel.state == .timedOut)
    }

    /// 화면이 유예 종료 갱신을 놓친 채 `같은 사진 다시 보내기`를 누르면 보내지 않고 시간 초과로 바꾼다.
    @Test func retryAfterLateRetryGraceTimesOutWithoutSending() async throws {
        let (viewModel, repository) = makeViewModel(uploadResults: [.networkFailure, .success])
        let photo = try #require(await capturedPhoto(viewModel))
        await viewModel.submit()

        serverClock.now = deadline.addingTimeInterval(VerificationSession.lateRetryGrace + 1)
        await viewModel.submit()

        #expect(viewModel.state == .timedOut)
        #expect(repository.submittedPhotoIDs == [photo.photo.id])
    }

    @Test func expiryCheckDatesAreDeadlineAndGraceEnd() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()

        #expect(viewModel.expiryCheckDates == [deadline, deadline.addingTimeInterval(VerificationSession.lateRetryGrace)])
    }

    @Test func retakeAfterDeadlineFromStartedUploadTimesOut() async throws {
        let (viewModel, _) = makeViewModel(uploadResults: [.networkFailure])
        _ = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()
        viewModel.returnToConfirm()
        serverClock.now = deadline
        viewModel.retake()

        #expect(viewModel.state == .timedOut)
    }

    // MARK: - 마감

    @Test func deadlineDuringCaptureTimesOut() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        await viewModel.startCapture()
        serverClock.now = deadline
        let expired = viewModel.expireIfNeeded()

        #expect(expired)
        #expect(viewModel.state == .timedOut)
    }

    @Test func deadlineOnConfirmTimesOutAndRetakeIsBlocked() async throws {
        let (viewModel, _) = makeViewModel()
        _ = try #require(await capturedPhoto(viewModel))

        serverClock.now = deadline
        viewModel.retake()

        #expect(viewModel.state == .timedOut)
    }

    @Test func submitNewPhotoAfterDeadlineTimesOut() async throws {
        let (viewModel, _) = makeViewModel()
        _ = try #require(await capturedPhoto(viewModel))

        // 화면이 마감 시각 갱신을 놓친 채 보내기를 누른 경우. 서버가 거절한다.
        serverClock.now = deadline.addingTimeInterval(1)
        await viewModel.submit()

        #expect(viewModel.state == .timedOut)
    }

    @Test func startCaptureAfterDeadlineTimesOut() async {
        let (viewModel, _) = makeViewModel()

        await viewModel.load()
        serverClock.now = deadline
        await viewModel.startCapture()

        #expect(viewModel.state == .timedOut)
    }

    /// 기기 시계가 서버보다 3분 빠르거나 느려도 마감은 서버 시각 기준으로 판단한다.
    @Test(arguments: [-180.0, 180.0])
    func deadlineUsesServerClockWhenDeviceClockIsSkewed(skew: TimeInterval) async {
        var tests = self
        tests.deviceSkew = skew
        let (viewModel, _) = tests.makeViewModel()

        await viewModel.load()
        await viewModel.startCapture()

        serverClock.now = deadline.addingTimeInterval(-1)
        #expect(viewModel.expireIfNeeded() == false)
        #expect(viewModel.timeUntilDeadline() == 1)
        #expect(viewModel.state == .capturing)

        serverClock.now = deadline
        #expect(viewModel.expireIfNeeded())
        #expect(viewModel.state == .timedOut)
    }

    @Test func capturedAtUsesServerClock() async throws {
        var tests = self
        tests.deviceSkew = 180
        let (viewModel, _) = tests.makeViewModel()

        let photo = try #require(await tests.capturedPhoto(viewModel))

        #expect(photo.photo.capturedAt == serverClock.now)
    }

    /// 실제 서버 모드: 마감 시각이 없으면 남은 시간·시간 초과 판단 없이 촬영을 받고, 마감은 제출 응답(403)에 맡긴다.
    @Test func openWithoutDeadlineNeverTimesOut() async {
        let (_, repository) = makeViewModel()
        let viewModel = CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: Self.makeCamera(),
            permission: FakeCameraPermission(),
            now: { [serverClock] in serverClock.now },
            state: .guide,
            session: VerificationSession(
                area: MockVerificationRepository.Fixture.area,
                window: MockVerificationRepository.Fixture.window,
                availability: .open(deadline: nil),
                serverNow: serverClock.now
            )
        )
        serverClock.now = serverClock.now.addingTimeInterval(24 * 60 * 60)

        #expect(viewModel.deadline == nil)
        #expect(viewModel.timeUntilDeadline() == nil)
        #expect(!viewModel.expireIfNeeded())
        await viewModel.startCapture()
        #expect(viewModel.state == .capturing)
    }

    @Test func checkUploadStatusShowsAlreadySubmittedWhenServerHasPhoto() async throws {
        let (viewModel, repository) = makeViewModel(uploadResults: [.success])
        _ = try #require(await capturedPhoto(viewModel))
        await viewModel.submit()
        // 응답 전에 마감 화면으로 넘어간 경우를 흉내 낸다.
        let timedOut = CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: Self.makeCamera(),
            permission: FakeCameraPermission(),
            state: .timedOut
        )

        await timedOut.checkUploadStatus()

        #expect(timedOut.sheet == .alreadySubmitted(submittedAt: Date(timeIntervalSinceReferenceDate: 0), status: .processing))
    }

    @Test func checkUploadStatusKeepsTimedOutWhenNothingSubmitted() async {
        let (viewModel, _) = makeViewModel()
        await viewModel.load()
        serverClock.now = deadline
        viewModel.expireIfNeeded()

        await viewModel.checkUploadStatus()

        #expect(viewModel.state == .timedOut)
        #expect(viewModel.sheet == nil)
    }

    // MARK: - 실제 서버 저장소

    /// 실제 서버 저장소와 묶은 VM. 오늘 인증 정보는 서버 시각 2026-09-29 08:00:00, 인증 시간 07:20~08:10이다.
    private static func makeServerViewModel(
        deviceNow: @escaping @MainActor () -> Date,
        log: RequestLog,
        submitResponse: @escaping @Sendable () -> (Int, Data)
    ) -> CameraVerificationViewModel {
        let httpClient = HTTPClient(
            baseURL: URL(string: "https://api.example.com")!,
            session: StubURLProtocol.makeSession { request in
                log.append(request)
                if request.url?.path() == "/api/v1/verifications/today" {
                    return (200, Data(#"""
                    {"serverTime":"2026-09-29T08:00:00.25","areaId":3,"areaName":"본관 2층 복도 A","cleanTime":"07:20~08:10",
                    "startTime":"07:20:00","endTime":"08:10:00","canSubmit":true,"unavailableReason":null,
                    "submitted":false,"verificationId":null,"status":null,"submittedAt":null}
                    """#.utf8))
                }
                return submitResponse()
            }
        )
        let store = InMemoryTokenStore(AuthTokens(accessToken: "access", refreshToken: "refresh"))
        let repository = VerificationRepositoryImpl(
            apiClient: APIClient(httpClient: httpClient, authSession: AuthSession(tokenStore: store, httpClient: httpClient)),
            now: { deviceNow() }
        )
        return CameraVerificationViewModel(
            fetchSessionUseCase: FetchVerificationSessionUseCase(verificationRepository: repository),
            submitPhotoUseCase: SubmitVerificationPhotoUseCase(verificationRepository: repository),
            camera: makeCamera(),
            permission: FakeCameraPermission(),
            now: { deviceNow() }
        )
    }

    private static func kst(_ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: hour, minute: minute, second: second))!
    }

    /// 기기 시계가 서버보다 10분 빠르거나 느려도 마감·남은 시간·전송 시작 시각은 서버 시각 기준이다.
    @Test(arguments: [-600.0, 600.0])
    func serverSessionCorrectsDeviceClock(skew: TimeInterval) async throws {
        let deviceClock = TestClock(now: Self.kst(8, 0).addingTimeInterval(skew))
        let log = RequestLog()
        let viewModel = Self.makeServerViewModel(deviceNow: { deviceClock.now }, log: log) {
            (201, Data(#"{"verificationId":7,"status":"PROCESSING","submittedAt":"2026-09-29T08:01:00"}"#.utf8))
        }

        _ = try #require(await capturedPhoto(viewModel))

        #expect(viewModel.deadline == Self.kst(8, 10))
        #expect(viewModel.timeUntilDeadline() == 600)
        #expect(viewModel.expireIfNeeded() == false)

        deviceClock.now = Self.kst(8, 1).addingTimeInterval(skew)
        await viewModel.submit()

        guard case .submitted = viewModel.state else {
            Issue.record("제출 완료가 아님: \(viewModel.state)")
            return
        }
        #expect(viewModel.submission == VerificationSubmission(id: "7", submittedAt: Self.kst(8, 1)))
        let upload = try #require(log.requests(path: "/api/v1/verifications").first)
        #expect(upload.value(forHTTPHeaderField: "X-Submit-Started-At") == "2026-09-29T08:01:00+09:00")

        deviceClock.now = Self.kst(8, 10).addingTimeInterval(skew - 1)
        #expect(viewModel.timeUntilDeadline() == 1)
    }

    /// 방학 기간이라 제출이 거절되면 `인증 시간 아님` 시트를 방학 사유로 띄운다.
    @Test func vacationOnSubmitShowsVacationSheet() async throws {
        let deviceClock = TestClock(now: Self.kst(8, 0))
        let viewModel = Self.makeServerViewModel(deviceNow: { deviceClock.now }, log: RequestLog()) {
            (403, Data(#"{"code":"VACATION_PERIOD","message":"m"}"#.utf8))
        }
        _ = try #require(await capturedPhoto(viewModel))

        await viewModel.submit()

        #expect(viewModel.sheet == .outsideWindow(.vacation))
        #expect(viewModel.sheet?.closesFlow == true)
    }
}
