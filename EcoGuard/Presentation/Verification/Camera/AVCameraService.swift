// AVCaptureSession은 Sendable 표시가 없지만 Apple 문서대로 전용 큐에서만 다룬다.
@preconcurrency import AVFoundation
import UIKit

/// AVFoundation 카메라. 세션 구성·시작·정지·촬영은 메인 스레드를 막지 않도록 전용 큐에서 한다.
final class AVCameraService: CameraService {
    private let controller = CaptureSessionController()

    var previewSource: CameraPreviewSource {
        .session(controller.session)
    }

    func events() -> AsyncStream<CameraEvent> {
        let session = controller.session
        return AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    let mapping: [(Notification.Name, CameraEvent)] = [
                        (AVCaptureSession.wasInterruptedNotification, .interrupted),
                        (AVCaptureSession.interruptionEndedNotification, .interruptionEnded),
                        (AVCaptureSession.runtimeErrorNotification, .runtimeError)
                    ]
                    for (name, event) in mapping {
                        group.addTask {
                            for await _ in NotificationCenter.default.notifications(named: name, object: session) {
                                continuation.yield(event)
                            }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func start() async throws {
        try await controller.perform { controller in
            try controller.configureIfNeeded()
            controller.startRunning()
        }
    }

    func stop() {
        controller.performWithoutWaiting { controller in
            controller.stopRunning()
        }
    }

    func switchPosition() async throws {
        try await controller.perform { controller in
            try controller.switchPosition()
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            controller.performWithoutWaiting { controller in
                controller.capturePhoto { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
}

/// 캡처 세션과 입력·출력. 모든 메서드는 `queue`에서만 부른다(`perform`으로 감싼다).
private nonisolated final class CaptureSessionController: @unchecked Sendable {
    enum CameraError: Error {
        case deviceUnavailable
        case cannotAddInput
        case cannotAddOutput
        /// 세션이 돌고 있지 않거나 중단돼 촬영 연결이 비활성이다.
        case connectionInactive
        case noImageData
    }

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "EcoGuard.camera.session")
    private var input: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .back
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    /// 촬영이 끝날 때까지 델리게이트를 붙잡아 둔다. `AVCapturePhotoOutput`은 델리게이트를 약하게 참조한다.
    private var inFlightCaptures: [Int64: PhotoCaptureDelegate] = [:]

    func perform(_ work: @escaping @Sendable (CaptureSessionController) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                continuation.resume(with: Result { try work(self) })
            }
        }
    }

    func performWithoutWaiting(_ work: @escaping @Sendable (CaptureSessionController) -> Void) {
        queue.async {
            work(self)
        }
    }

    func configureIfNeeded() throws {
        guard input == nil else { return }
        try configure(position: position)
    }

    func switchPosition() throws {
        try configure(position: position == .back ? .front : .back)
    }

    func startRunning() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stopRunning() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping @Sendable (Result<Data, Error>) -> Void) {
        guard let connection = photoOutput.connection(with: .video), connection.isActive, connection.isEnabled else {
            completion(.failure(CameraError.connectionInactive))
            return
        }
        // 앱은 세로 고정이라 기기 방향으로 회전을 정한다. 가로로 들고 찍으면 가로 사진이 된다.
        if let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelCapture,
           connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
        let settings = AVCapturePhotoSettings()
        let uniqueID = settings.uniqueID
        let delegate = PhotoCaptureDelegate { [weak self] result in
            self?.queue.async {
                self?.inFlightCaptures[uniqueID] = nil
            }
            completion(result)
        }
        inFlightCaptures[uniqueID] = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func configure(position: AVCaptureDevice.Position) throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CameraError.deviceUnavailable
        }
        let newInput = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        if let input {
            session.removeInput(input)
        }
        guard session.canAddInput(newInput) else {
            if let input {
                session.addInput(input)
            }
            throw CameraError.cannotAddInput
        }
        session.addInput(newInput)
        if !session.outputs.contains(photoOutput) {
            guard session.canAddOutput(photoOutput) else { throw CameraError.cannotAddOutput }
            session.addOutput(photoOutput)
        }
        if let connection = photoOutput.connection(with: .video), connection.isVideoMirroringSupported {
            // 미리보기 레이어는 전면일 때 거울처럼 보여 주지만, 저장 사진은 실제 방향으로 둔다.
            // iOS 기본 카메라의 '전면 카메라 미러링' 기본값(끔)과 같고, 사진 속 글자·표지판이 뒤집히지 않아 검수에 맞다.
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        input = newInput
        self.position = position
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
    }
}

/// `AVCapturePhotoOutput`이 임의의 큐에서 부르므로 액터에 묶지 않는다.
private nonisolated final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CaptureSessionController.CameraError.noImageData))
            return
        }
        completion(.success(data))
    }
}
